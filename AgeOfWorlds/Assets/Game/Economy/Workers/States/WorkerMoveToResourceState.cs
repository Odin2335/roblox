using AgeOfWorlds.Units.States;

namespace AgeOfWorlds.Economy.Workers.States
{
    public class WorkerMoveToResourceState : IUnitState
    {
        private readonly Worker worker;
        private int attempts;

        public WorkerMoveToResourceState(Worker worker)
        {
            this.worker = worker;
        }

        public UnitStateId Id => UnitStateId.MovingToResource;

        public void Enter()
        {
            attempts = 0;
            MoveToNode();
        }

        public void Tick(float deltaTime)
        {
            ResourceNode node = worker.CurrentResourceNode;
            if (!Worker.IsNodeValid(node))
            {
                worker.HandleNodeLost();
                return;
            }

            if (worker.IsInReach(node.GetClosestPoint(worker.transform.position)))
            {
                worker.Unit.StateMachine.ChangeState(new WorkerGatherState(worker));
                return;
            }

            if (worker.Unit.Movement.UpdateArrival(deltaTime))
            {
                attempts++;
                if (attempts >= worker.MaxApproachAttempts)
                {
                    worker.HandleNodeUnreachable();
                }
                else
                {
                    MoveToNode();
                }
            }
        }

        public void Exit()
        {
        }

        private void MoveToNode()
        {
            ResourceNode node = worker.CurrentResourceNode;
            if (Worker.IsNodeValid(node))
            {
                worker.Unit.Movement.MoveTo(node.GetClosestPoint(worker.transform.position));
            }
        }
    }
}
