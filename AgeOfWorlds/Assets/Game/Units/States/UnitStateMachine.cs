using System;

namespace AgeOfWorlds.Units.States
{
    public class UnitStateMachine
    {
        public IUnitState Current { get; private set; }
        public UnitStateId CurrentId => Current?.Id ?? UnitStateId.Idle;

        /// <summary>Raised after a state has been entered. Used e.g. for idle-worker detection.</summary>
        public event Action<IUnitState> StateChanged;

        public void ChangeState(IUnitState next)
        {
            Current?.Exit();
            Current = next;
            Current?.Enter();

            // Enter() may already have switched to another state; only report the state that stuck.
            if (Current == next)
            {
                StateChanged?.Invoke(next);
            }
        }

        public void Tick(float deltaTime)
        {
            Current?.Tick(deltaTime);
        }
    }
}
