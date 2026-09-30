using AgeOfWorlds.Units.States;
using UnityEngine;

namespace AgeOfWorlds.Economy.Workers.States
{
    /// <summary>
    /// Prepared for the repair system: walks to the target and stays there.
    /// Health restoration and resource cost are added with buildings (Phase 3+).
    /// </summary>
    public class WorkerRepairState : IUnitState
    {
        private readonly Worker worker;
        private readonly Transform site;
        private readonly Collider siteCollider;

        public WorkerRepairState(Worker worker, Transform site)
        {
            this.worker = worker;
            this.site = site;
            siteCollider = site != null ? site.GetComponentInChildren<Collider>() : null;
        }

        public UnitStateId Id => UnitStateId.Repair;

        public void Enter()
        {
            if (site != null)
            {
                worker.Unit.Movement.MoveTo(ClosestPoint());
            }
        }

        public void Tick(float deltaTime)
        {
            if (site == null)
            {
                worker.GoIdle();
                return;
            }

            if (worker.IsInReach(ClosestPoint()))
            {
                worker.Unit.Movement.Stop();
                worker.Unit.Movement.FaceTowards(site.position);
                // Later: restore health and consume Wood/Metal here.
            }
            else
            {
                worker.Unit.Movement.UpdateArrival(deltaTime);
            }
        }

        public void Exit()
        {
        }

        private Vector3 ClosestPoint() => InteractionUtility.ClosestPoint(siteCollider, site, worker.transform.position);
    }
}
