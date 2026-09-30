using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Core.Players;
using AgeOfWorlds.Units;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// Tracks current population (sum of unit PopulationCost, via unit events) and
    /// maximum population (starting capacity + providers such as houses, capped by the hard cap).
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class PopulationManager : MonoBehaviour
    {
        private PlayerManager playerManager;
        private bool initialized;

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnEnable()
        {
            EventBus.Subscribe<PlayersInitializedEvent>(OnPlayersInitialized);
            EventBus.Subscribe<UnitCreatedEvent>(OnUnitCreated);
            EventBus.Subscribe<UnitRemovedEvent>(OnUnitRemoved);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<PlayersInitializedEvent>(OnPlayersInitialized);
            EventBus.Unsubscribe<UnitCreatedEvent>(OnUnitCreated);
            EventBus.Unsubscribe<UnitRemovedEvent>(OnUnitRemoved);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public int GetCurrent(int playerId) => GetPlayer(playerId)?.Population.Current ?? 0;

        public int GetMax(int playerId) => GetPlayer(playerId)?.Population.Max ?? 0;

        /// <summary>True if a unit with this population cost could be added now.</summary>
        public bool HasRoomFor(int playerId, int populationCost)
        {
            PlayerState player = GetPlayer(playerId);
            return player != null && player.Population.Current + populationCost <= player.Population.Max;
        }

        /// <summary>Called by population providers (houses, town centers) in Phase 3.</summary>
        public void AddCapacity(int playerId, int amount)
        {
            PlayerState player = GetPlayer(playerId);
            if (player == null || amount == 0)
            {
                return;
            }

            player.Population.Capacity = Mathf.Max(0, player.Population.Capacity + amount);
            Publish(player);
        }

        public void RemoveCapacity(int playerId, int amount) => AddCapacity(playerId, -amount);

        private void OnPlayersInitialized(PlayersInitializedEvent evt)
        {
            playerManager = GameServices.Get<PlayerManager>();
            GameManager gameManager = GameServices.Get<GameManager>();
            MatchConfig config = gameManager != null ? gameManager.MatchConfig : null;

            foreach (PlayerState player in playerManager.Players)
            {
                player.Population.Capacity = config != null ? config.StartingPopulationCapacity : 10;
                player.Population.HardCap = config != null ? config.PopulationHardCap : 200;
                player.Population.Current = 0;
            }

            // Units placed in the scene registered before the players existed: count them now.
            UnitManager unitManager = GameServices.Get<UnitManager>();
            if (unitManager != null)
            {
                IReadOnlyList<Unit> units = unitManager.Units;
                for (int i = 0; i < units.Count; i++)
                {
                    PlayerState owner = playerManager.GetPlayer(units[i].OwnerId);
                    if (owner != null)
                    {
                        owner.Population.Current += PopulationCostOf(units[i]);
                    }
                }
            }

            initialized = true;
            foreach (PlayerState player in playerManager.Players)
            {
                Publish(player);
            }
        }

        private void OnUnitCreated(UnitCreatedEvent evt) => ChangeCurrent(evt.Unit, +1);

        private void OnUnitRemoved(UnitRemovedEvent evt) => ChangeCurrent(evt.Unit, -1);

        private void ChangeCurrent(Unit unit, int sign)
        {
            if (!initialized)
            {
                return;
            }

            PlayerState player = GetPlayer(unit.OwnerId);
            if (player == null)
            {
                return;
            }

            player.Population.Current = Mathf.Max(0, player.Population.Current + sign * PopulationCostOf(unit));
            Publish(player);
        }

        private static int PopulationCostOf(Unit unit) => unit.Data != null ? unit.Data.PopulationCost : 0;

        private void Publish(PlayerState player)
        {
            EventBus.Publish(new PopulationChangedEvent(player.PlayerId, player.Population.Current, player.Population.Max));
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
