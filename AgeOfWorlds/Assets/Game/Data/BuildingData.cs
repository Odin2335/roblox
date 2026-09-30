using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Data
{
    [CreateAssetMenu(menuName = "Age of Worlds/Building Data", fileName = "NewBuilding")]
    public class BuildingData : ScriptableObject
    {
        [Header("Identity")]
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField, TextArea] private string description;
        [SerializeField] private EraData era;
        [SerializeField] private BuildingType buildingType;
        [SerializeField] private GameObject prefab;
        [SerializeField] private Sprite icon;

        [Header("Defense")]
        [SerializeField, Min(1f)] private float maxHealth = 1000f;
        [SerializeField, Min(0f)] private float armor = 5f;
        [SerializeField] private ArmorType armorType = ArmorType.Building;

        [Header("Placement")]
        [Tooltip("Size in world units on X and Z.")]
        [SerializeField] private Vector2 footprint = new Vector2(4f, 4f);

        [Header("Cost")]
        [SerializeField] private ResourceCost cost = new ResourceCost(0, 100, 0, 0);
        [Tooltip("Seconds for a single worker.")]
        [SerializeField, Min(0.1f)] private float buildTime = 30f;

        [Header("Function")]
        [SerializeField, Min(0)] private int populationProvided;
        [SerializeField] private List<UnitData> unitsProduced = new List<UnitData>();
        [SerializeField] private List<TechnologyData> technologiesAvailable = new List<TechnologyData>();

        [Header("Requirements")]
        [SerializeField] private EraData requiredEra;
        [SerializeField] private TechnologyData requiredTechnology;

        public string ID => id;
        public string DisplayName => string.IsNullOrEmpty(displayName) ? name : displayName;
        public string Description => description;
        public EraData Era => era;
        public BuildingType BuildingType => buildingType;
        public GameObject Prefab => prefab;
        public Sprite Icon => icon;

        public float MaxHealth => maxHealth;
        public float Armor => armor;
        public ArmorType ArmorType => armorType;
        public Vector2 Footprint => footprint;

        public ResourceCost Cost => cost;
        public int FoodCost => cost.Food;
        public int WoodCost => cost.Wood;
        public int MetalCost => cost.Metal;
        public int EnergyCost => cost.Energy;
        public float BuildTime => buildTime;

        public int PopulationProvided => populationProvided;
        public IReadOnlyList<UnitData> UnitsProduced => unitsProduced;
        public IReadOnlyList<TechnologyData> TechnologiesAvailable => technologiesAvailable;

        public EraData RequiredEra => requiredEra;
        public TechnologyData RequiredTechnology => requiredTechnology;
    }
}
