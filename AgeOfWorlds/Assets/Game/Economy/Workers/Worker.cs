using AgeOfWorlds.Core;
using AgeOfWorlds.Data;
using AgeOfWorlds.Economy.Workers.States;
using AgeOfWorlds.Units;
using AgeOfWorlds.Units.States;
using UnityEngine;

namespace AgeOfWorlds.Economy.Workers
{
    /// <summary>
    /// Worker capability for any unit. One class handles every resource type: the type
    /// comes from the node being worked, so the same villager can chop wood, then mine metal,
    /// then gather food. Gathering is tick-based (driven by UnitManager's state ticks).
    /// </summary>
    [RequireComponent(typeof(Unit))]
    public class Worker : MonoBehaviour, IResourceGatherer
    {
        [Tooltip("Extra distance (beyond the unit radius) at which the worker can touch a node or drop-off.")]
        [SerializeField, Min(0.1f)] private float interactionReach = 0.8f;
        [Tooltip("Search radius for a replacement node of the same type when the current one runs out.")]
        [SerializeField, Min(1f)] private float nodeSearchRadius = 25f;
        [Tooltip("How often a worker retries reaching a node or drop-off before giving up.")]
        [SerializeField, Min(1)] private int maxApproachAttempts = 3;

        private Unit unit;
        private ResourceLocator locator;
        private ResourceManager resourceManager;
        private bool isIdle;
        private float gatherProgress;
        private bool hasLastNode;
        private Vector3 lastNodePosition;
        private ResourceType lastNodeType;

        public Unit Unit => unit != null ? unit : unit = GetComponent<Unit>();
        public int MaxApproachAttempts => maxApproachAttempts;

        // IResourceGatherer. Carry capacity and gather rate come from UnitData;
        // technology modifiers are applied here once the runtime stat system exists (Phase 6).
        public int CarryCapacity => Unit.Data != null ? Unit.Data.CarryCapacity : 10;
        public float GatherRate => Unit.Data != null ? Unit.Data.GatherRate : 1f;
        public int CurrentCarryAmount { get; private set; }
        public ResourceType CarriedResourceType { get; private set; }
        public ResourceNode CurrentResourceNode { get; private set; }
        public IResourceDropOff CurrentDropOff { get; private set; }

        public bool IsCarrying => CurrentCarryAmount > 0;
        public bool IsFull => CurrentCarryAmount >= CarryCapacity;
        public bool IsIdle => isIdle;

        private void OnEnable()
        {
            locator = GameServices.Get<ResourceLocator>();
            resourceManager = GameServices.Get<ResourceManager>();
            Unit.StateMachine.StateChanged += OnStateChanged;
            SetIdle(Unit.StateMachine.CurrentId == UnitStateId.Idle);
        }

        private void OnDisable()
        {
            Unit.StateMachine.StateChanged -= OnStateChanged;
            SetIdle(false);
        }

        // ---------- Commands ----------

        public void BeginGathering(ResourceNode node)
        {
            if (!IsNodeValid(node))
            {
                return;
            }

            // Switching to a different resource type drops the current load.
            if (IsCarrying && CarriedResourceType != node.ResourceType)
            {
                DropCargo();
            }

            SetNode(node);
            Unit.StateMachine.ChangeState(new WorkerMoveToResourceState(this));
        }

        /// <param name="preferred">Optional drop-off chosen by the player; null = nearest valid one.</param>
        public void ReturnCargo(IResourceDropOff preferred = null)
        {
            if (IsCarrying)
            {
                Unit.StateMachine.ChangeState(new WorkerReturnResourceState(this, preferred));
            }
        }

        /// <summary>Prepared for Phase 3 (construction). Not issued by the player yet.</summary>
        public void BeginBuilding(Transform constructionSite)
        {
            Unit.StateMachine.ChangeState(new WorkerBuildState(this, constructionSite));
        }

        /// <summary>Prepared for the repair system. Not issued by the player yet.</summary>
        public void BeginRepairing(Transform target)
        {
            Unit.StateMachine.ChangeState(new WorkerRepairState(this, target));
        }

        // ---------- Used by worker states ----------

        public bool IsInReach(Vector3 closestPoint, float extraSlack = 0f)
        {
            return InteractionUtility.FlatDistance(transform.position, closestPoint) <=
                   Unit.Movement.Radius + interactionReach + extraSlack;
        }

        /// <summary>Advances gathering by one tick. Returns the amount taken from the node.</summary>
        public int GatherTick(float deltaTime)
        {
            ResourceNode node = CurrentResourceNode;
            if (!IsNodeValid(node) || IsFull)
            {
                return 0;
            }

            gatherProgress += GatherRate * node.GatherRateModifier * deltaTime;
            int whole = Mathf.FloorToInt(gatherProgress);
            if (whole <= 0)
            {
                return 0;
            }

            gatherProgress -= whole;
            int taken = node.Extract(Mathf.Min(whole, CarryCapacity - CurrentCarryAmount));
            if (taken > 0)
            {
                if (CurrentCarryAmount == 0)
                {
                    CarriedResourceType = node.ResourceType;
                }

                CurrentCarryAmount += taken;
            }

            return taken;
        }

        public IResourceDropOff FindDropOff(IResourceDropOff preferred)
        {
            if (IsDropOffValid(preferred) && preferred.OwnerId == Unit.OwnerId && preferred.Accepts(CarriedResourceType))
            {
                return preferred;
            }

            return locator != null ? locator.FindNearestDropOff(Unit.OwnerId, CarriedResourceType, transform.position) : null;
        }

        public void SetDropOff(IResourceDropOff dropOff) => CurrentDropOff = dropOff;

        public void Deposit(IResourceDropOff dropOff)
        {
            if (!IsCarrying || !IsDropOffValid(dropOff))
            {
                return;
            }

            resourceManager?.Add(Unit.OwnerId, CarriedResourceType, CurrentCarryAmount);
            CurrentCarryAmount = 0;
        }

        /// <summary>After depositing: back to the previous node, else a nearby one of the same type, else idle.</summary>
        public void ContinueAfterDeposit()
        {
            if (IsNodeValid(CurrentResourceNode) || TryFindReplacementNode(null))
            {
                Unit.StateMachine.ChangeState(new WorkerMoveToResourceState(this));
            }
            else
            {
                GoIdle();
            }
        }

        /// <summary>The current node is gone (depleted/destroyed).</summary>
        public void HandleNodeLost()
        {
            if (TryFindReplacementNode(null))
            {
                if (IsFull)
                {
                    ReturnCargo();
                }
                else
                {
                    Unit.StateMachine.ChangeState(new WorkerMoveToResourceState(this));
                }
            }
            else if (IsCarrying)
            {
                ReturnCargo();
            }
            else
            {
                GoIdle();
            }
        }

        /// <summary>The current node could not be reached: try another one nearby.</summary>
        public void HandleNodeUnreachable()
        {
            if (TryFindReplacementNode(CurrentResourceNode))
            {
                Unit.StateMachine.ChangeState(new WorkerMoveToResourceState(this));
            }
            else
            {
                GoIdle();
            }
        }

        public void GoIdle()
        {
            Unit.StateMachine.ChangeState(new UnitIdleState(Unit));
        }

        public static bool IsNodeValid(ResourceNode node) => node != null && node.isActiveAndEnabled && !node.IsDepleted;

        /// <summary>Unity-aware null check for interface references (destroyed objects compare unequal to null).</summary>
        public static bool IsDropOffValid(IResourceDropOff dropOff) =>
            dropOff is Object unityObject && unityObject != null && dropOff.IsOperational;

        // ---------- Internals ----------

        private bool TryFindReplacementNode(ResourceNode exclude)
        {
            if (!hasLastNode || locator == null)
            {
                return false;
            }

            ResourceNode replacement = locator.FindNearestNode(lastNodeType, lastNodePosition, nodeSearchRadius, exclude);
            if (replacement == null)
            {
                CurrentResourceNode = null;
                return false;
            }

            SetNode(replacement);
            return true;
        }

        private void SetNode(ResourceNode node)
        {
            if (node != CurrentResourceNode)
            {
                gatherProgress = 0f;
            }

            CurrentResourceNode = node;
            lastNodeType = node.ResourceType;
            lastNodePosition = node.transform.position;
            hasLastNode = true;
        }

        private void DropCargo()
        {
            CurrentCarryAmount = 0;
            gatherProgress = 0f;
        }

        private void OnStateChanged(IUnitState state)
        {
            SetIdle(state.Id == UnitStateId.Idle);
        }

        private void SetIdle(bool idle)
        {
            if (isIdle == idle)
            {
                return;
            }

            isIdle = idle;
            EventBus.Publish(new WorkerIdleChangedEvent(this, idle));
        }
    }
}
