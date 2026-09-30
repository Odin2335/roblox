namespace AgeOfWorlds.Units.States
{
    public class UnitStateMachine
    {
        public IUnitState Current { get; private set; }
        public UnitStateId CurrentId => Current?.Id ?? UnitStateId.Idle;

        public void ChangeState(IUnitState next)
        {
            Current?.Exit();
            Current = next;
            Current?.Enter();
        }

        public void Tick(float deltaTime)
        {
            Current?.Tick(deltaTime);
        }
    }
}
