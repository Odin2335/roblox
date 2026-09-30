using AgeOfWorlds.Units.States;
using UnityEngine;

namespace AgeOfWorlds.Economy.Workers.States
{
    /// <summary>
    /// Prepared for Phase 3: walks to the construction site and stays there.
    /// Construction progress is added when buildings exist.
    /// </summary>
    public class WorkerBuildState : IUnitState
    {
        private readonly Worker worker;
        private readonly Transform site;
        private readonly Collider siteCollider;

        public WorkerBuildState(Worker worker, Transform site)
        {
            this.worker = worker;
            this.site = site;
            siteCollider = site != null ? site.GetComponentInChildren<Collider>() : null;
        }

        public UnitStateId Id => UnitStateId.Build;

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
                // Phase 3: add construction progress to the building here.
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
