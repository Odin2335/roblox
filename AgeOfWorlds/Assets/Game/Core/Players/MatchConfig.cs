using System;
using System.Collections.Generic;
using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Core.Players
{
    [Serializable]
    public class PlayerSetup
    {
        public string DisplayName = "Player";
        public int Team;
        public FactionData Faction;
        public Color Color = Color.blue;
        public bool IsAI;
    }

    /// <summary>Describes who plays a match. Player IDs are the list indices.</summary>
    [CreateAssetMenu(menuName = "Age of Worlds/Match Config", fileName = "MatchConfig")]
    public class MatchConfig : ScriptableObject
    {
        [SerializeField] private List<PlayerSetup> players = new List<PlayerSetup>
        {
            new PlayerSetup { DisplayName = "Player", Team = 0, Color = new Color(0.2f, 0.5f, 1f), IsAI = false },
            new PlayerSetup { DisplayName = "AI", Team = 1, Color = new Color(1f, 0.25f, 0.2f), IsAI = true }
        };

        [SerializeField] private int localPlayerId;
        [SerializeField] private EraData startingEra;

        public IReadOnlyList<PlayerSetup> Players => players;
        public int LocalPlayerId => localPlayerId;
        public EraData StartingEra => startingEra;
    }
}
