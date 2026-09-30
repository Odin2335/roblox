using UnityEngine;

namespace AgeOfWorlds.Units.States
{
    public class UnitMoveState : IUnitState
    {
        private readonly Unit unit;
        private readonly Vector3 destination;

        public UnitMoveState(Unit unit, Vector3 destination)
        {
            this.unit = unit;
            this.destination = destination;
        }

        public UnitStateId Id => UnitStateId.Move;

        public void Enter()
        {
            if (!unit.Movement.MoveTo(destination))
            {
                Debug.LogWarning($"[UnitMoveState] {unit.name} could not path to {destination}. Is it on a baked NavMesh?", unit);
            }
        }

        public void Tick(float deltaTime)
        {
            if (unit.Movement.UpdateArrival(deltaTime))
            {
                unit.StateMachine.ChangeState(new UnitIdleState(unit));
            }
        }

        public void Exit()
        {
        }
    }
}
