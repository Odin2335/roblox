using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Data
{
    [CreateAssetMenu(menuName = "Age of Worlds/Technology Data", fileName = "NewTechnology")]
    public class TechnologyData : ScriptableObject
    {
        [Header("Identity")]
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField, TextArea] private string description;
        [SerializeField] private Sprite icon;
        [SerializeField] private EraData era;
        [SerializeField] private TechnologyCategory category;

        [Header("Research")]
        [SerializeField, Min(0.1f)] private float researchTime = 30f;
        [SerializeField] private ResourceCost resourceCost = new ResourceCost(100, 0, 50, 0);

        [Header("Requirements")]
        [SerializeField] private List<TechnologyData> requiredTechnologies = new List<TechnologyData>();
        [SerializeField] private BuildingData requiredBuilding;

        [Header("Unlocks")]
        [SerializeField] private List<UnitData> unlocksUnits = new List<UnitData>();
        [SerializeField] private List<BuildingData> unlocksBuildings = new List<BuildingData>();
        [SerializeField] private List<TechnologyData> unlocksTechnologies = new List<TechnologyData>();

        [Header("Effects")]
        [SerializeField] private List<StatModifier> statModifiers = new List<StatModifier>();

        public string ID => id;
        public string DisplayName => string.IsNullOrEmpty(displayName) ? name : displayName;
        public string Description => description;
        public Sprite Icon => icon;
        public EraData Era => era;
        public TechnologyCategory Category => category;

        public float ResearchTime => researchTime;
        public ResourceCost ResourceCost => resourceCost;

        public IReadOnlyList<TechnologyData> RequiredTechnologies => requiredTechnologies;
        public BuildingData RequiredBuilding => requiredBuilding;

        public IReadOnlyList<UnitData> UnlocksUnits => unlocksUnits;
        public IReadOnlyList<BuildingData> UnlocksBuildings => unlocksBuildings;
        public IReadOnlyList<TechnologyData> UnlocksTechnologies => unlocksTechnologies;

        public IReadOnlyList<StatModifier> StatModifiers => statModifiers;
    }
}
