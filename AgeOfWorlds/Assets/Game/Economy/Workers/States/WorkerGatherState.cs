using AgeOfWorlds.Units.States;

namespace AgeOfWorlds.Economy.Workers.States
{
    /// <summary>Gathers in state ticks (10 Hz), never per frame.</summary>
    public class WorkerGatherState : IUnitState
    {
        // Tolerance so small separation pushes do not interrupt gathering.
        private const float ReachSlack = 0.5f;

        private readonly Worker worker;

        public WorkerGatherState(Worker worker)
        {
            this.worker = worker;
        }

        public UnitStateId Id => UnitStateId.Gather;

        public void Enter()
        {
            worker.Unit.Movement.Stop();
            if (Worker.IsNodeValid(worker.CurrentResourceNode))
            {
                worker.Unit.Movement.FaceTowards(worker.CurrentResourceNode.transform.position);
            }
        }

        public void Tick(float deltaTime)
        {
            if (worker.IsFull)
            {
                worker.ReturnCargo();
                return;
            }

            ResourceNode node = worker.CurrentResourceNode;
            if (!Worker.IsNodeValid(node))
            {
                worker.HandleNodeLost();
                return;
            }

            if (!worker.IsInReach(node.GetClosestPoint(worker.transform.position), ReachSlack))
            {
                worker.Unit.StateMachine.ChangeState(new WorkerMoveToResourceState(worker));
                return;
            }

            worker.GatherTick(deltaTime);

            if (worker.IsFull)
            {
                worker.ReturnCargo();
            }
        }

        public void Exit()
        {
        }
    }
}
