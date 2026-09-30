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

        [Header("Economy")]
        [SerializeField] private ResourceCost startingResources = new ResourceCost(200, 200, 100, 0);
        [Tooltip("Population capacity before any houses or town centers are counted.")]
        [SerializeField, Min(0)] private int startingPopulationCapacity = 10;
        [Tooltip("Absolute population limit, no matter how many houses exist.")]
        [SerializeField, Min(1)] private int populationHardCap = 200;

        public IReadOnlyList<PlayerSetup> Players => players;
        public int LocalPlayerId => localPlayerId;
        public EraData StartingEra => startingEra;
        public ResourceCost StartingResources => startingResources;
        public int StartingPopulationCapacity => startingPopulationCapacity;
        public int PopulationHardCap => populationHardCap;
    }
}
