using System;
using UnityEngine;

namespace AgeOfWorlds.Data
{
    [Serializable]
    public struct ResourceCost
    {
        [Min(0)] public int Food;
        [Min(0)] public int Wood;
        [Min(0)] public int Metal;
        [Min(0)] public int Energy;

        public ResourceCost(int food, int wood, int metal, int energy)
        {
            Food = food;
            Wood = wood;
            Metal = metal;
            Energy = energy;
        }

        public int this[ResourceType type]
        {
            get
            {
                switch (type)
                {
                    case ResourceType.Food: return Food;
                    case ResourceType.Wood: return Wood;
                    case ResourceType.Metal: return Metal;
                    case ResourceType.Energy: return Energy;
                    default: throw new ArgumentOutOfRangeException(nameof(type), type, null);
                }
            }
        }

        public bool IsFree => Food == 0 && Wood == 0 && Metal == 0 && Energy == 0;

        public ResourceCost Scaled(float factor)
        {
            return new ResourceCost(
                Mathf.FloorToInt(Food * factor),
                Mathf.FloorToInt(Wood * factor),
                Mathf.FloorToInt(Metal * factor),
                Mathf.FloorToInt(Energy * factor));
        }

        public override string ToString() => $"F{Food} W{Wood} M{Metal} E{Energy}";
    }
}
