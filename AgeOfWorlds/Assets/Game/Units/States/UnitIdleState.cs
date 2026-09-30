namespace AgeOfWorlds.Units.States
{
    /// <summary>Does nothing yet. Later: stance-based target scanning, idle worker notification.</summary>
    public class UnitIdleState : IUnitState
    {
        private readonly Unit unit;

        public UnitIdleState(Unit unit)
        {
            this.unit = unit;
        }

        public UnitStateId Id => UnitStateId.Idle;

        public void Enter()
        {
            unit.Movement.Stop();
        }

        public void Tick(float deltaTime)
        {
        }

        public void Exit()
        {
        }
    }
}
