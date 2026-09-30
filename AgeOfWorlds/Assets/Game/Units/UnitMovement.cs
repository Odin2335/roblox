using AgeOfWorlds.Data;
using UnityEngine;
using UnityEngine.AI;

namespace AgeOfWorlds.Units
{
    /// <summary>
    /// Shared movement for every unit type, built on NavMeshAgent.
    /// Heavy units (mechs) differ only by data: speed, acceleration, turn speed, radius.
    /// Per-frame work is driven by UnitManager, not by Update() on each unit.
    /// </summary>
    [RequireComponent(typeof(NavMeshAgent))]
    public class UnitMovement : MonoBehaviour
    {
        private const int MovingAvoidancePriority = 40;
        private const int IdleAvoidancePriority = 60;

        [Tooltip("1 = full speed while turning. Lower values make heavy units turn before accelerating.")]
        [SerializeField, Range(0.05f, 1f)] private float minSpeedWhileTurning = 1f;
        [Tooltip("If no progress is made for this long, the unit accepts its current position (prevents crowds blocking forever).")]
        [SerializeField] private float stuckTimeout = 1.25f;
        [Tooltip("Distance to the destination under which a stuck unit counts as arrived.")]
        [SerializeField] private float stuckArrivalDistance = 3f;
        [SerializeField] private float stuckGiveUpTime = 5f;

        private NavMeshAgent agent;
        private float baseSpeed;
        private float turnSpeed = 540f;
        private Vector3 separationVelocity;

        private float bestRemainingDistance;
        private float timeWithoutProgress;

        public bool IsMoving { get; private set; }
        public float Radius => Agent.radius;
        public Vector3 Velocity => Agent.velocity;
        public Vector3 Destination { get; private set; }

        // Lazy: Unit.OnEnable may run before this component's Awake.
        private NavMeshAgent Agent
        {
            get
            {
                if (agent == null)
                {
                    agent = GetComponent<NavMeshAgent>();
                    agent.updateRotation = false;
                    agent.autoBraking = true;
                }

                return agent;
            }
        }

        public void Configure(UnitData data)
        {
            if (data == null)
            {
                return;
            }

            baseSpeed = data.MovementSpeed;
            turnSpeed = data.TurnSpeed;
            Agent.speed = baseSpeed;
            Agent.acceleration = data.Acceleration;
            Agent.angularSpeed = data.TurnSpeed;
            Agent.radius = data.Radius;
            Agent.avoidancePriority = IdleAvoidancePriority;
        }

        /// <summary>Called by the runtime stat system later when movement speed modifiers change.</summary>
        public void SetBaseSpeed(float speed)
        {
            baseSpeed = speed;
            Agent.speed = speed;
        }

        public bool MoveTo(Vector3 destination)
        {
            if (!Agent.isOnNavMesh)
            {
                return false;
            }

            if (NavMesh.SamplePosition(destination, out NavMeshHit hit, 4f, Agent.areaMask))
            {
                destination = hit.position;
            }

            Destination = destination;
            Agent.isStopped = false;
            Agent.avoidancePriority = MovingAvoidancePriority;
            IsMoving = Agent.SetDestination(destination);
            bestRemainingDistance = float.MaxValue;
            timeWithoutProgress = 0f;
            return IsMoving;
        }

        public void Stop()
        {
            if (Agent.isOnNavMesh)
            {
                Agent.ResetPath();
            }

            IsMoving = false;
            Agent.avoidancePriority = IdleAvoidancePriority;
        }

        /// <summary>Checks arrival and crowd-stuck situations. Called on state ticks.</summary>
        public bool UpdateArrival(float deltaTime)
        {
            if (!IsMoving)
            {
                return true;
            }

            if (Agent.pathPending)
            {
                return false;
            }

            float remaining = Agent.remainingDistance;
            bool reached = remaining <= Agent.stoppingDistance + 0.1f;
            if (reached || Agent.pathStatus == NavMeshPathStatus.PathInvalid)
            {
                Stop();
                return true;
            }

            if (remaining < bestRemainingDistance - 0.1f)
            {
                bestRemainingDistance = remaining;
                timeWithoutProgress = 0f;
                return false;
            }

            timeWithoutProgress += deltaTime;
            bool closeEnough = remaining <= stuckArrivalDistance && timeWithoutProgress >= stuckTimeout;
            if (closeEnough || timeWithoutProgress >= stuckGiveUpTime)
            {
                Stop();
                return true;
            }

            return false;
        }

        /// <summary>Push applied to idle units that overlap (set by UnitManager's separation pass).</summary>
        public void SetSeparationVelocity(Vector3 velocity)
        {
            separationVelocity = velocity;
        }

        /// <summary>Per-frame visual work: smooth rotation, turn slowdown, separation.</summary>
        public void TickFrame(float deltaTime)
        {
            Vector3 velocity = Agent.velocity;
            velocity.y = 0f;
            Vector3 desired = IsMoving ? Agent.desiredVelocity : velocity;
            desired.y = 0f;

            if (desired.sqrMagnitude > 0.01f)
            {
                Quaternion targetRotation = Quaternion.LookRotation(desired);
                transform.rotation = Quaternion.RotateTowards(transform.rotation, targetRotation, turnSpeed * deltaTime);

                if (minSpeedWhileTurning < 1f)
                {
                    float alignment = Mathf.Clamp01(Vector3.Dot(transform.forward, desired.normalized));
                    Agent.speed = baseSpeed * Mathf.Lerp(minSpeedWhileTurning, 1f, alignment);
                }
            }

            if (!IsMoving && separationVelocity.sqrMagnitude > 0.0001f && Agent.isOnNavMesh)
            {
                Agent.Move(separationVelocity * deltaTime);
                separationVelocity = Vector3.MoveTowards(separationVelocity, Vector3.zero, 4f * deltaTime);
            }
        }
    }
}
