using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Economy.Workers;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// Keeps a per-player list of idle workers. Prepared for the idle-worker button
    /// and notification (Phase 10); the resource bar already shows the count.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class IdleWorkerTracker : MonoBehaviour
    {
        private readonly Dictionary<int, List<Worker>> idleByPlayer = new Dictionary<int, List<Worker>>();
        private readonly Dictionary<int, int> cycleIndex = new Dictionary<int, int>();

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnEnable()
        {
            EventBus.Subscribe<WorkerIdleChangedEvent>(OnWorkerIdleChanged);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<WorkerIdleChangedEvent>(OnWorkerIdleChanged);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public int GetIdleCount(int playerId) => idleByPlayer.TryGetValue(playerId, out List<Worker> list) ? list.Count : 0;

        public IReadOnlyList<Worker> GetIdleWorkers(int playerId) =>
            idleByPlayer.TryGetValue(playerId, out List<Worker> list) ? list : (IReadOnlyList<Worker>)System.Array.Empty<Worker>();

        /// <summary>Cycles through idle workers, for the future "next idle worker" button/hotkey.</summary>
        public Worker GetNextIdleWorker(int playerId)
        {
            if (!idleByPlayer.TryGetValue(playerId, out List<Worker> list) || list.Count == 0)
            {
                return null;
            }

            cycleIndex.TryGetValue(playerId, out int index);
            index = (index + 1) % list.Count;
            cycleIndex[playerId] = index;
            return list[index];
        }

        private void OnWorkerIdleChanged(WorkerIdleChangedEvent evt)
        {
            int playerId = evt.Worker.Unit.OwnerId;
            if (!idleByPlayer.TryGetValue(playerId, out List<Worker> list))
            {
                list = new List<Worker>();
                idleByPlayer.Add(playerId, list);
            }

            bool changed = evt.IsIdle ? AddUnique(list, evt.Worker) : list.Remove(evt.Worker);
            if (changed)
            {
                EventBus.Publish(new IdleWorkerCountChangedEvent(playerId, list.Count));
            }
        }

        private static bool AddUnique(List<Worker> list, Worker worker)
        {
            if (list.Contains(worker))
            {
                return false;
            }

            list.Add(worker);
            return true;
        }
    }
}
