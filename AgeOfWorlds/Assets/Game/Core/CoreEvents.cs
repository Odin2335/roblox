namespace AgeOfWorlds.Core
{
    public readonly struct GameStateChangedEvent
    {
        public readonly GameState Previous;
        public readonly GameState Current;

        public GameStateChangedEvent(GameState previous, GameState current)
        {
            Previous = previous;
            Current = current;
        }
    }

    public readonly struct PlayersInitializedEvent
    {
        public readonly int LocalPlayerId;

        public PlayersInitializedEvent(int localPlayerId)
        {
            LocalPlayerId = localPlayerId;
        }
    }

    public readonly struct MatchEndedEvent
    {
        public readonly int WinningTeam;
        public readonly bool LocalPlayerWon;

        public MatchEndedEvent(int winningTeam, bool localPlayerWon)
        {
            WinningTeam = winningTeam;
            LocalPlayerWon = localPlayerWon;
        }
    }
}
