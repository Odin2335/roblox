using UnityEngine;

namespace AgeOfWorlds.Data
{
    /// <summary>
    /// Base definition of a unit. Never modified at runtime: upgrades go through
    /// player modifiers applied by the runtime stat system.
    /// </summary>
    [CreateAssetMenu(menuName = "Age of Worlds/Unit Data", fileName = "NewUnit")]
    public class UnitData : ScriptableObject
    {
        [Header("Identity")]
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField, TextArea] private string description;
        [SerializeField] private EraData era;
        [SerializeField] private UnitType unitType;
        [SerializeField] private GameObject prefab;
        [SerializeField] private Sprite icon;

        [Header("Defense")]
        [SerializeField, Min(1f)] private float maxHealth = 100f;
        [SerializeField, Min(0f)] private float armor;
        [SerializeField] private ArmorType armorType = ArmorType.Light;
        [Tooltip("What this unit counts as when others decide whether they can attack it.")]
        [SerializeField] private TargetType targetCategory = TargetType.Infantry;

        [Header("Movement")]
        [SerializeField, Min(0f)] private float movementSpeed = 4f;
        [Tooltip("Low values give heavy units (mechs) slow acceleration.")]
        [SerializeField, Min(0.1f)] private float acceleration = 16f;
        [Tooltip("Degrees per second. Low values give heavy turning.")]
        [SerializeField, Min(1f)] private float turnSpeed = 540f;
        [Tooltip("Collision / avoidance radius. Mechs use large values.")]
        [SerializeField, Min(0.1f)] private float radius = 0.5f;
        [SerializeField, Min(0f)] private float visionRange = 10f;

        [Header("Attack")]
        [SerializeField, Min(0f)] private float attackRange = 1.5f;
        [SerializeField, Min(0f)] private float attackDamage = 10f;
        [Tooltip("Attacks per second.")]
        [SerializeField, Min(0.01f)] private float attackSpeed = 1f;
        [SerializeField] private DamageType damageType = DamageType.Melee;
        [SerializeField] private TargetType targetTypes = TargetType.Infantry | TargetType.Cavalry | TargetType.Building;

        [Header("Worker (used only if the prefab has a Worker component)")]
        [Tooltip("Resource units carried per trip.")]
        [SerializeField, Min(1)] private int carryCapacity = 10;
        [Tooltip("Resource units gathered per second, before node and technology modifiers.")]
        [SerializeField, Min(0.01f)] private float gatherRate = 1f;

        [Header("Cost")]
        [SerializeField] private ResourceCost cost = new ResourceCost(50, 0, 0, 0);
        [SerializeField, Min(0)] private int populationCost = 1;
        [Tooltip("Seconds.")]
        [SerializeField, Min(0.1f)] private float buildTime = 10f;

        [Header("Requirements")]
        [SerializeField] private BuildingData requiredBuilding;
        [SerializeField] private TechnologyData requiredTechnology;

        public string ID => id;
        public string DisplayName => string.IsNullOrEmpty(displayName) ? name : displayName;
        public string Description => description;
        public EraData Era => era;
        public UnitType UnitType => unitType;
        public GameObject Prefab => prefab;
        public Sprite Icon => icon;

        public float MaxHealth => maxHealth;
        public float Armor => armor;
        public ArmorType ArmorType => armorType;
        public TargetType TargetCategory => targetCategory;

        public float MovementSpeed => movementSpeed;
        public float Acceleration => acceleration;
        public float TurnSpeed => turnSpeed;
        public float Radius => radius;
        public float VisionRange => visionRange;

        public float AttackRange => attackRange;
        public float AttackDamage => attackDamage;
        public float AttackSpeed => attackSpeed;
        public DamageType DamageType => damageType;
        public TargetType TargetTypes => targetTypes;

        public int CarryCapacity => carryCapacity;
        public float GatherRate => gatherRate;

        public ResourceCost Cost => cost;
        public int FoodCost => cost.Food;
        public int WoodCost => cost.Wood;
        public int MetalCost => cost.Metal;
        public int EnergyCost => cost.Energy;
        public int PopulationCost => populationCost;
        public float BuildTime => buildTime;

        public BuildingData RequiredBuilding => requiredBuilding;
        public TechnologyData RequiredTechnology => requiredTechnology;

        public bool CanTarget(TargetType category) => (targetTypes & category) != 0;
    }
}
