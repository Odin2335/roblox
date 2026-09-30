using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Core.Players
{
    public enum PlayerRelation
    {
        Self,
        Ally,
        Enemy,
        Neutral
    }

    /// <summary>Creates and stores all players of the current match.</summary>
    [DefaultExecutionOrder(-150)]
    public class PlayerManager : MonoBehaviour
    {
        public const int NeutralPlayerId = -1;

        private readonly List<PlayerState> players = new List<PlayerState>();

        public IReadOnlyList<PlayerState> Players => players;
        public int LocalPlayerId { get; private set; }
        public PlayerState LocalPlayer => GetPlayer(LocalPlayerId);

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public void InitializePlayers(MatchConfig config)
        {
            players.Clear();
            for (int i = 0; i < config.Players.Count; i++)
            {
                PlayerSetup setup = config.Players[i];
                players.Add(new PlayerState(i, setup.DisplayName, setup.Team, setup.Faction, setup.Color, setup.IsAI));
            }

            LocalPlayerId = config.LocalPlayerId;
            EventBus.Publish(new PlayersInitializedEvent(LocalPlayerId));
        }

        public PlayerState GetPlayer(int playerId)
        {
            return playerId >= 0 && playerId < players.Count ? players[playerId] : null;
        }

        public PlayerRelation GetRelation(int fromPlayerId, int toPlayerId)
        {
            if (fromPlayerId == toPlayerId)
            {
                return PlayerRelation.Self;
            }

            PlayerState from = GetPlayer(fromPlayerId);
            PlayerState to = GetPlayer(toPlayerId);
            if (from == null || to == null)
            {
                return PlayerRelation.Neutral;
            }

            return from.Team == to.Team ? PlayerRelation.Ally : PlayerRelation.Enemy;
        }

        public bool AreEnemies(int playerA, int playerB) => GetRelation(playerA, playerB) == PlayerRelation.Enemy;
    }
}
