using System;
using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Data
{
    /// <summary>
    /// A runtime stat change granted by a technology. Applied as a player-wide modifier,
    /// so current and future units are affected without touching any asset.
    /// </summary>
    [Serializable]
    public class StatModifier
    {
        [SerializeField] private StatType stat;
        [SerializeField] private ModifierOperation operation = ModifierOperation.Percent;
        [SerializeField] private float value = 0.1f;

        [Tooltip("Empty = applies to all unit types.")]
        [SerializeField] private List<UnitType> affectedUnitTypes = new List<UnitType>();

        [Tooltip("Empty = applies to all building types.")]
        [SerializeField] private List<BuildingType> affectedBuildingTypes = new List<BuildingType>();

        public StatType Stat => stat;
        public ModifierOperation Operation => operation;
        public float Value => value;
        public IReadOnlyList<UnitType> AffectedUnitTypes => affectedUnitTypes;
        public IReadOnlyList<BuildingType> AffectedBuildingTypes => affectedBuildingTypes;

        public bool AppliesTo(UnitType unitType) => affectedUnitTypes.Count == 0 || affectedUnitTypes.Contains(unitType);

        public bool AppliesTo(BuildingType buildingType) =>
            affectedBuildingTypes.Count == 0 || affectedBuildingTypes.Contains(buildingType);
    }
}
