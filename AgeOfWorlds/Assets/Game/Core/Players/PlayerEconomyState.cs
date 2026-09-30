using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Core.Players
{
    /// <summary>Stockpile of one player. Only ResourceManager writes to it.</summary>
    public class PlayerResources
    {
        private readonly int[] amounts = new int[ResourceTypeUtility.Count];

        public int Get(ResourceType type) => amounts[(int)type];

        internal void Set(ResourceType type, int amount) => amounts[(int)type] = Mathf.Max(0, amount);
    }

    /// <summary>Population of one player. Only PopulationManager writes to it.</summary>
    public class PlayerPopulation
    {
        public int Current { get; internal set; }
        /// <summary>Sum of starting capacity and all population providers (houses, town centers).</summary>
        public int Capacity { get; internal set; }
        public int HardCap { get; internal set; }
        public int Max => Mathf.Min(Capacity, HardCap);
    }
}
