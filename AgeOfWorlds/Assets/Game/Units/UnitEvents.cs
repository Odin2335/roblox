namespace AgeOfWorlds.Units
{
    public readonly struct UnitCreatedEvent
    {
        public readonly Unit Unit;
        public UnitCreatedEvent(Unit unit) => Unit = unit;
    }

    /// <summary>Raised whenever a unit leaves the game (death, pooling, destroy).</summary>
    public readonly struct UnitRemovedEvent
    {
        public readonly Unit Unit;
        public UnitRemovedEvent(Unit unit) => Unit = unit;
    }
}
