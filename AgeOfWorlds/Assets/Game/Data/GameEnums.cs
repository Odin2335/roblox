using System;

namespace AgeOfWorlds.Data
{
    public enum ResourceType
    {
        Food,
        Wood,
        Metal,
        Energy
    }

    public enum UnitType
    {
        Worker,
        Infantry,
        Ranged,
        Cavalry,
        Siege,
        Vehicle,
        Artillery,
        Mech,
        Support
    }

    public enum BuildingType
    {
        TownCenter,
        House,
        Production,
        Research,
        DropOff,
        Defense,
        Economy
    }

    public enum DamageType
    {
        Melee,
        Piercing,
        Ballistic,
        Explosive,
        Energy,
        AntiArmor
    }

    public enum ArmorType
    {
        Unarmored,
        Light,
        Heavy,
        Vehicle,
        Building,
        Mech
    }

    /// <summary>What a unit counts as when targeted, and (as a mask) what it may attack.</summary>
    [Flags]
    public enum TargetType
    {
        None = 0,
        Infantry = 1 << 0,
        Cavalry = 1 << 1,
        Vehicle = 1 << 2,
        Mech = 1 << 3,
        Building = 1 << 4,
        Air = 1 << 5
    }

    public enum TechnologyCategory
    {
        Economy,
        Military,
        Defense,
        Technology,
        EraProgression
    }

    public enum StatType
    {
        MaxHealth,
        Armor,
        AttackDamage,
        AttackSpeed,
        AttackRange,
        MovementSpeed,
        VisionRange,
        GatherRate,
        CarryCapacity,
        BuildSpeed,
        BuildingMaxHealth,
        BuildingArmor,
        ProductionSpeed,
        ResearchSpeed
    }

    public enum ModifierOperation
    {
        /// <summary>Adds a flat value, e.g. +2 armor.</summary>
        Flat,
        /// <summary>Adds a percentage of the base value, e.g. 0.1 = +10%. Percentages stack additively.</summary>
        Percent
    }
}
