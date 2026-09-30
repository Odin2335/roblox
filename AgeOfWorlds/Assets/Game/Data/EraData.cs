using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Data
{
    /// <summary>
    /// One era. Eras are ordered by EraNumber, so adding era 5..12 only needs new assets.
    /// Requirements describe what is needed to advance INTO this era.
    /// </summary>
    [CreateAssetMenu(menuName = "Age of Worlds/Era Data", fileName = "NewEra")]
    public class EraData : ScriptableObject
    {
        [Header("Identity")]
        [SerializeField] private string eraId;
        [SerializeField] private string displayName;
        [SerializeField, Min(1)] private int eraNumber = 1;

        [Header("Advancement requirements")]
        [SerializeField] private ResourceCost requiredResources;
        [SerializeField, Min(0)] private int requiredPopulation;
        [SerializeField] private List<TechnologyData> requiredTechnologies = new List<TechnologyData>();
        [SerializeField] private List<BuildingData> requiredBuildings = new List<BuildingData>();
        [Tooltip("Seconds.")]
        [SerializeField, Min(0f)] private float advancementTime = 60f;

        [Header("Unlocks")]
        [SerializeField] private List<UnitData> unitsUnlocked = new List<UnitData>();
        [SerializeField] private List<BuildingData> buildingsUnlocked = new List<BuildingData>();
        [SerializeField] private List<TechnologyData> technologiesUnlocked = new List<TechnologyData>();

        public string EraID => eraId;
        public string DisplayName => string.IsNullOrEmpty(displayName) ? name : displayName;
        public int EraNumber => eraNumber;

        public ResourceCost RequiredResources => requiredResources;
        public int RequiredPopulation => requiredPopulation;
        public IReadOnlyList<TechnologyData> RequiredTechnologies => requiredTechnologies;
        public IReadOnlyList<BuildingData> RequiredBuildings => requiredBuildings;
        public float AdvancementTime => advancementTime;

        public IReadOnlyList<UnitData> UnitsUnlocked => unitsUnlocked;
        public IReadOnlyList<BuildingData> BuildingsUnlocked => buildingsUnlocked;
        public IReadOnlyList<TechnologyData> TechnologiesUnlocked => technologiesUnlocked;
    }
}
