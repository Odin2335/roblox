using AgeOfWorlds.Core;
using AgeOfWorlds.Core.Players;
using AgeOfWorlds.Data;
using AgeOfWorlds.Economy;
using TMPro;
using UnityEngine;

namespace AgeOfWorlds.UserInterface
{
    /// <summary>
    /// Top bar: Food, Wood, Metal, Energy, Population and idle workers of the local player.
    /// Purely event-driven, no polling.
    /// </summary>
    public class ResourceBarUI : MonoBehaviour
    {
        [SerializeField] private TMP_Text foodText;
        [SerializeField] private TMP_Text woodText;
        [SerializeField] private TMP_Text metalText;
        [SerializeField] private TMP_Text energyText;
        [SerializeField] private TMP_Text populationText;
        [Tooltip("Optional.")]
        [SerializeField] private TMP_Text idleWorkersText;
        [Tooltip("Population text turns this color when the cap is reached.")]
        [SerializeField] private Color populationFullColor = new Color(1f, 0.4f, 0.3f);

        private Color populationDefaultColor = Color.white;
        private int localPlayerId;

        private void Awake()
        {
            if (populationText != null)
            {
                populationDefaultColor = populationText.color;
            }
        }

        private void OnEnable()
        {
            EventBus.Subscribe<PlayersInitializedEvent>(OnPlayersInitialized);
            EventBus.Subscribe<ResourceChangedEvent>(OnResourceChanged);
            EventBus.Subscribe<PopulationChangedEvent>(OnPopulationChanged);
            EventBus.Subscribe<IdleWorkerCountChangedEvent>(OnIdleWorkersChanged);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<PlayersInitializedEvent>(OnPlayersInitialized);
            EventBus.Unsubscribe<ResourceChangedEvent>(OnResourceChanged);
            EventBus.Unsubscribe<PopulationChangedEvent>(OnPopulationChanged);
            EventBus.Unsubscribe<IdleWorkerCountChangedEvent>(OnIdleWorkersChanged);
        }

        private void Start()
        {
            // In case the match was initialized before this UI enabled.
            PlayerManager players = GameServices.Get<PlayerManager>();
            if (players != null && players.LocalPlayer != null)
            {
                localPlayerId = players.LocalPlayerId;
                RefreshAll();
            }
        }

        private void OnPlayersInitialized(PlayersInitializedEvent evt)
        {
            localPlayerId = evt.LocalPlayerId;
            RefreshAll();
        }

        private void OnResourceChanged(ResourceChangedEvent evt)
        {
            if (evt.PlayerId == localPlayerId)
            {
                SetResource(evt.Type, evt.Amount);
            }
        }

        private void OnPopulationChanged(PopulationChangedEvent evt)
        {
            if (evt.PlayerId == localPlayerId)
            {
                SetPopulation(evt.Current, evt.Max);
            }
        }

        private void OnIdleWorkersChanged(IdleWorkerCountChangedEvent evt)
        {
            if (evt.PlayerId == localPlayerId)
            {
                SetIdleWorkers(evt.Count);
            }
        }

        private void RefreshAll()
        {
            ResourceManager resources = GameServices.Get<ResourceManager>();
            if (resources != null)
            {
                foreach (ResourceType type in ResourceTypeUtility.All)
                {
                    SetResource(type, resources.GetAmount(localPlayerId, type));
                }
            }

            PopulationManager population = GameServices.Get<PopulationManager>();
            if (population != null)
            {
                SetPopulation(population.GetCurrent(localPlayerId), population.GetMax(localPlayerId));
            }

            IdleWorkerTracker idle = GameServices.Get<IdleWorkerTracker>();
            SetIdleWorkers(idle != null ? idle.GetIdleCount(localPlayerId) : 0);
        }

        private void SetResource(ResourceType type, int amount)
        {
            TMP_Text text = type switch
            {
                ResourceType.Food => foodText,
                ResourceType.Wood => woodText,
                ResourceType.Metal => metalText,
                ResourceType.Energy => energyText,
                _ => null
            };

            if (text != null)
            {
                text.text = $"{type}: {amount}";
            }
        }

        private void SetPopulation(int current, int max)
        {
            if (populationText == null)
            {
                return;
            }

            populationText.text = $"Population: {current} / {max}";
            populationText.color = current >= max ? populationFullColor : populationDefaultColor;
        }

        private void SetIdleWorkers(int count)
        {
            if (idleWorkersText != null)
            {
                idleWorkersText.text = count > 0 ? $"Idle workers: {count}" : string.Empty;
            }
        }
    }
}
