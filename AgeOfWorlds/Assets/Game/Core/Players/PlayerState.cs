using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Core.Players
{
    /// <summary>
    /// Runtime state of one player. Plain C# so it can be serialized for saves later.
    /// Era, technologies and owned objects are added in the phases that introduce them.
    /// </summary>
    public class PlayerState
    {
        public int PlayerId { get; }
        public string DisplayName { get; }
        public int Team { get; }
        public FactionData Faction { get; }
        public Color Color { get; }
        public bool IsAI { get; }
        public PlayerResources Resources { get; } = new PlayerResources();
        public PlayerPopulation Population { get; } = new PlayerPopulation();

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
