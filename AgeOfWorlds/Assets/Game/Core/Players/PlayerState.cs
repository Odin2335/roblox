using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Core.Players
{
    /// <summary>
    /// Runtime state of one player. Plain C# so it can be serialized for saves later.
    /// Resources, population and era are added in the phases that introduce them.
    /// </summary>
    public class PlayerState
    {
        public int PlayerId { get; }
        public string DisplayName { get; }
        public int Team { get; }
        public FactionData Faction { get; }
        public Color Color { get; }
        public bool IsAI { get; }

        public PlayerState(int playerId, string displayName, int team, FactionData faction, Color color, bool isAI)
        {
            PlayerId = playerId;
            DisplayName = displayName;
            Team = team;
            Faction = faction;
            Color = color;
            IsAI = isAI;
        }
    }
}
