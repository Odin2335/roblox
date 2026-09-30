namespace AgeOfWorlds.Units.States
{
    /// <summary>A reusable unit behaviour. Ticked by UnitManager at a fixed interval, not every frame.</summary>
    public interface IUnitState
    {
        UnitStateId Id { get; }
        void Enter();
        void Tick(float deltaTime);
        void Exit();
    }
}
