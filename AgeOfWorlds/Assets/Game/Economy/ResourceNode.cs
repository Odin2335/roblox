using AgeOfWorlds.Core;
using AgeOfWorlds.Core.Players;
using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// A gatherable resource source (berry bush, tree, ore vein, energy crystal).
    /// Food/Tree/Metal/Energy nodes are prefabs of this one component with a different ResourceType.
    /// </summary>
    public class ResourceNode : MonoBehaviour, ISelectable
    {
        public enum DepletedBehaviour
        {
            Destroy,
            Deactivate
        }

        [SerializeField] private ResourceType resourceType = ResourceType.Wood;
        [SerializeField, Min(1)] private int maxAmount = 200;
        [Tooltip("Multiplies the worker's gather rate. 0.5 = half as fast, 2 = twice as fast.")]
        [SerializeField, Min(0.01f)] private float gatherRateModifier = 1f;
        [SerializeField] private string displayName;
        [SerializeField] private Sprite icon;
        [SerializeField, Min(0.1f)] private float selectionRadius = 1f;
        [SerializeField] private DepletedBehaviour whenDepleted = DepletedBehaviour.Destroy;
        [Tooltip("Optional. Used for reach checks. Defaults to the first collider on this object or its children.")]
        [SerializeField] private Collider interactionCollider;

        private ResourceLocator locator;

        public ResourceType ResourceType => resourceType;
        public int MaxAmount => maxAmount;
        public int RemainingAmount { get; private set; }
        public float GatherRateModifier => gatherRateModifier;
        public bool IsDepleted => RemainingAmount <= 0;

        // ISelectable
        public Transform Transform => transform;
        public int OwnerId => PlayerManager.NeutralPlayerId;
        public bool IsSelectable => isActiveAndEnabled && !IsDepleted;
        public float SelectionRadius => selectionRadius;
        public string DisplayName => string.IsNullOrEmpty(displayName) ? resourceType.ToString() : displayName;
        public Sprite Icon => icon;
        public float CurrentHealth => RemainingAmount;
        public float MaxHealth => maxAmount;

        private void Awake()
        {
            RemainingAmount = maxAmount;
            if (interactionCollider == null)
            {
                interactionCollider = GetComponentInChildren<Collider>();
            }
        }

        private void OnEnable()
        {
            locator = GameServices.Get<ResourceLocator>();
            locator?.Register(this);
        }

        private void OnDisable()
        {
            locator?.Unregister(this);
            locator = null;
        }

        public Vector3 GetClosestPoint(Vector3 from) => InteractionUtility.ClosestPoint(interactionCollider, transform, from);

        /// <summary>Removes up to the requested amount and returns what was actually taken.</summary>
        public int Extract(int requested)
        {
            if (requested <= 0 || IsDepleted)
            {
                return 0;
            }

            int taken = Mathf.Min(requested, RemainingAmount);
            RemainingAmount -= taken;

            if (IsDepleted)
            {
                OnDepleted();
            }

            return taken;
        }

        private void OnDepleted()
        {
            EventBus.Publish(new ResourceNodeDepletedEvent(this));

            if (whenDepleted == DepletedBehaviour.Destroy)
            {
                Destroy(gameObject);
            }
            else
            {
                gameObject.SetActive(false);
            }
        }
    }
}
