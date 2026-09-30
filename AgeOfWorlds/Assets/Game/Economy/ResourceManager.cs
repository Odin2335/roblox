using AgeOfWorlds.Core;
using AgeOfWorlds.Core.Players;
using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// The only system that changes player stockpiles. Everyone else asks it
    /// (CanAfford / TrySpend / Add) and the UI listens to ResourceChangedEvent.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class ResourceManager : MonoBehaviour
    {
        private PlayerManager playerManager;

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnEnable()
        {
            EventBus.Subscribe<PlayersInitializedEvent>(OnPlayersInitialized);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<PlayersInitializedEvent>(OnPlayersInitialized);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public int GetAmount(int playerId, ResourceType type)
        {
            PlayerState player = GetPlayer(playerId);
            return player != null ? player.Resources.Get(type) : 0;
        }

        public bool CanAfford(int playerId, ResourceCost cost)
        {
            PlayerState player = GetPlayer(playerId);
            if (player == null)
            {
                return false;
            }

            foreach (ResourceType type in ResourceTypeUtility.All)
            {
                if (player.Resources.Get(type) < cost[type])
                {
                    return false;
                }
            }

            return true;
        }

        /// <summary>Deducts the full cost, or nothing if the player cannot afford it.</summary>
        public bool TrySpend(int playerId, ResourceCost cost)
        {
            if (!CanAfford(playerId, cost))
            {
                return false;
            }

            foreach (ResourceType type in ResourceTypeUtility.All)
            {
                Change(playerId, type, -cost[type]);
            }

            return true;
        }

        public void Add(int playerId, ResourceType type, int amount)
        {
            if (amount > 0)
            {
                Change(playerId, type, amount);
            }
        }

        /// <summary>Adds a whole bundle, e.g. refunds for cancelled production.</summary>
        public void Add(int playerId, ResourceCost amounts)
        {
            foreach (ResourceType type in ResourceTypeUtility.All)
            {
                Add(playerId, type, amounts[type]);
            }
        }

        private void Change(int playerId, ResourceType type, int delta)
        {
            if (delta == 0)
            {
                return;
            }

            PlayerState player = GetPlayer(playerId);
            if (player == null)
            {
                return;
            }

            int newAmount = Mathf.Max(0, player.Resources.Get(type) + delta);
            player.Resources.Set(type, newAmount);
            EventBus.Publish(new ResourceChangedEvent(playerId, type, newAmount, delta));
        }

        private void OnPlayersInitialized(PlayersInitializedEvent evt)
        {
            playerManager = GameServices.Get<PlayerManager>();
            GameManager gameManager = GameServices.Get<GameManager>();
            ResourceCost starting = gameManager != null && gameManager.MatchConfig != null
                ? gameManager.MatchConfig.StartingResources
                : default;

            foreach (PlayerState player in playerManager.Players)
            {
                foreach (ResourceType type in ResourceTypeUtility.All)
                {
                    player.Resources.Set(type, starting[type]);
                    EventBus.Publish(new ResourceChangedEvent(player.PlayerId, type, starting[type], starting[type]));
                }
            }
        }

        private PlayerState GetPlayer(int playerId)
        {
            if (playerManager == null)
            {
                playerManager = GameServices.Get<PlayerManager>();
            }

            return playerManager != null ? playerManager.GetPlayer(playerId) : null;
        }
    }
}
