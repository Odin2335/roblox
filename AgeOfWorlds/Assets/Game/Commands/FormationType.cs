namespace AgeOfWorlds.Commands
{
    public enum FormationType
    {
        Loose,
        Line,
        Box
    }

    public readonly struct FormationChangedEvent
    {
        public readonly FormationType Formation;
        public FormationChangedEvent(FormationType formation) => Formation = formation;
    }
}
