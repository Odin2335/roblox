using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Core.Spatial;
using AgeOfWorlds.Units.States;
using UnityEngine;

namespace AgeOfWorlds.Units
{
    /// <summary>
    /// Tracks all units and drives them: per-frame movement visuals, and interval-based
    /// state ticks and separation. Individual units have no Update().
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class UnitManager : MonoBehaviour
    {
        [Header("Ticks")]
        [Tooltip("Seconds between state machine ticks (10 Hz default).")]
        [SerializeField] private float stateTickInterval = 0.1f;

        [Header("Separation")]
        [SerializeField] private float spatialCellSize = 4f;
        [Tooltip("How strongly overlapping idle units push apart (units per second per unit of overlap).")]
        [SerializeField] private float separationStrength = 3f;

        private readonly List<Unit> units = new List<Unit>();
        private readonly List<Unit> queryBuffer = new List<Unit>();
        private SpatialHashGrid<Unit> grid;
        private float tickTimer;
        private float largestRadius = 0.5f;

        public IReadOnlyList<Unit> Units => units;

        private void Awake()
        {
            grid = new SpatialHashGrid<Unit>(spatialCellSize);
            GameServices.Register(this);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public void Register(Unit unit)
        {
            if (unit.RegistryIndex >= 0)
            {
                return;
            }

            unit.RegistryIndex = units.Count;
            units.Add(unit);
            largestRadius = Mathf.Max(largestRadius, unit.Movement.Radius);
            EventBus.Publish(new UnitCreatedEvent(unit));
        }

        public void Unregister(Unit unit)
        {
            int index = unit.RegistryIndex;
            if (index < 0 || index >= units.Count || units[index] != unit)
            {
                return;
            }

            int last = units.Count - 1;
            units[index] = units[last];
            units[index].RegistryIndex = index;
            units.RemoveAt(last);
            unit.RegistryIndex = -1;
            EventBus.Publish(new UnitRemovedEvent(unit));
        }

        /// <summary>Fills results with units within radius. Uses the grid built on the last tick.</summary>
        public void QueryRadius(Vector3 center, float radius, List<Unit> results)
        {
            grid.Query(center, radius, results);
        }

        public void GetUnitsOwnedBy(int ownerId, List<Unit> results)
        {
            for (int i = 0; i < units.Count; i++)
            {
                if (units[i].OwnerId == ownerId)
                {
                    results.Add(units[i]);
                }
            }
        }

        private void Update()
        {
            float deltaTime = Time.deltaTime;
            if (deltaTime <= 0f)
            {
                return;
            }

            for (int i = units.Count - 1; i >= 0; i--)
            {
                units[i].Movement.TickFrame(deltaTime);
            }

            tickTimer += deltaTime;
            if (tickTimer < stateTickInterval)
            {
                return;
            }

            float tickDelta = tickTimer;
            tickTimer = 0f;

            RebuildGrid();

            // Iterate backwards: states may remove units (death) during the tick.
            for (int i = units.Count - 1; i >= 0; i--)
            {
                if (i < units.Count)
                {
                    units[i].StateMachine.Tick(tickDelta);
                }
            }

            ApplySeparation();
        }

        private void RebuildGrid()
        {
            grid.Clear();
            for (int i = 0; i < units.Count; i++)
            {
                grid.Insert(units[i]);
            }
        }

        /// <summary>Pushes overlapping idle units apart. Moving units rely on NavMeshAgent avoidance.</summary>
        private void ApplySeparation()
        {
            for (int i = 0; i < units.Count; i++)
            {
                Unit unit = units[i];
                if (unit.StateMachine.CurrentId != UnitStateId.Idle)
                {
                    continue;
                }

                Vector3 position = unit.transform.position;
                float radius = unit.Movement.Radius;

                queryBuffer.Clear();
                grid.Query(position, radius + largestRadius, queryBuffer);

                Vector3 push = Vector3.zero;
                for (int n = 0; n < queryBuffer.Count; n++)
                {
                    Unit other = queryBuffer[n];
                    if (other == unit)
                    {
                        continue;
                    }

                    Vector3 offset = position - other.transform.position;
                    offset.y = 0f;
                    float minDistance = radius + other.Movement.Radius;
                    float distance = offset.magnitude;
                    if (distance >= minDistance)
                    {
                        continue;
                    }

                    // Perfectly stacked units: separate deterministically by registry order.
                    Vector3 direction = distance > 0.001f
                        ? offset / distance
                        : Quaternion.Euler(0f, unit.RegistryIndex * 137.5f, 0f) * Vector3.forward;
                    push += direction * (minDistance - distance);
                }

                if (push.sqrMagnitude > 0.0001f)
                {
                    unit.Movement.SetSeparationVelocity(push * separationStrength);
                }
            }
        }
    }
}
