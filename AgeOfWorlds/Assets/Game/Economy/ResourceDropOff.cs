using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// Drop-off capability. Put it on any building prefab (Town Center, Lumber Camp, Mining Camp,
    /// Power Plant ...) and configure AcceptedResourceTypes. In Phase 3 the Building component
    /// sets the owner and the operational state when construction finishes.
    /// </summary>
    public class ResourceDropOff : MonoBehaviour, IResourceDropOff
    {
        [SerializeField] private int ownerId;
        [SerializeField] private List<ResourceType> acceptedResourceTypes = new List<ResourceType>
        {
            ResourceType.Food,
            ResourceType.Wood,
            ResourceType.Metal,
            ResourceType.Energy
        };
        [SerializeField] private bool isOperational = true;
        [Tooltip("Optional. Used for reach checks. Defaults to the first collider on this object or its children.")]
        [SerializeField] private Collider interactionCollider;

        private ResourceLocator locator;

        public Transform Transform => transform;
        public int OwnerId => ownerId;
        public bool IsOperational => isOperational && isActiveAndEnabled;
        public IReadOnlyList<ResourceType> AcceptedResourceTypes => acceptedResourceTypes;

        private void Awake()
        {
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

        public bool Accepts(ResourceType type) => acceptedResourceTypes.Contains(type);

        public Vector3 GetClosestPoint(Vector3 from) => InteractionUtility.ClosestPoint(interactionCollider, transform, from);

        /// <summary>Used by spawned buildings (Phase 3).</summary>
        public void SetOwner(int owner) => ownerId = owner;

        public void SetOperational(bool operational) => isOperational = operational;
    }
}
