using AgeOfWorlds.Units.States;
using UnityEngine;

namespace AgeOfWorlds.Economy.Workers.States
{
    public class WorkerReturnResourceState : IUnitState
    {
        private readonly Worker worker;
        private readonly IResourceDropOff preferred;
        private int attempts;

        public WorkerReturnResourceState(Worker worker, IResourceDropOff preferred)
        {
            this.worker = worker;
            this.preferred = preferred;
        }

        public UnitStateId Id => UnitStateId.ReturnResource;

        public void Enter()
        {
            attempts = 0;
            if (!AcquireDropOff(preferred))
            {
                worker.GoIdle();
            }
        }

        public void Tick(float deltaTime)
        {
            if (!worker.IsCarrying)
            {
                worker.ContinueAfterDeposit();
                return;
            }

            IResourceDropOff dropOff = worker.CurrentDropOff;
            if (!Worker.IsDropOffValid(dropOff) || !dropOff.Accepts(worker.CarriedResourceType))
            {
                if (!AcquireDropOff(null))
                {
                    worker.GoIdle();
                }

                return;
            }

            if (worker.IsInReach(dropOff.GetClosestPoint(worker.transform.position)))
            {
                worker.Deposit(dropOff);
                worker.ContinueAfterDeposit();
                return;
            }

            if (worker.Unit.Movement.UpdateArrival(deltaTime))
            {
                attempts++;
                if (attempts >= worker.MaxApproachAttempts)
                {
                    worker.GoIdle();
                }
                else
                {
                    MoveTo(dropOff);
                }
            }
        }

        public void Exit()
        {
        }

        private bool AcquireDropOff(IResourceDropOff candidate)
        {
            IResourceDropOff dropOff = worker.FindDropOff(candidate);
            worker.SetDropOff(dropOff);
            if (dropOff == null)
            {
                Debug.LogWarning($"[Worker] {worker.name} found no drop-off accepting {worker.CarriedResourceType}.", worker);
                return false;
            }

            MoveTo(dropOff);
            return true;
        }

        private void MoveTo(IResourceDropOff dropOff)
        {
            worker.Unit.Movement.MoveTo(dropOff.GetClosestPoint(worker.transform.position));
        }
    }
}
