using AgeOfWorlds.Core.Players;
using AgeOfWorlds.InputHandling;
using UnityEngine;

namespace AgeOfWorlds.Core
{
    /// <summary>
    /// Owns only the match lifecycle: initialization, pause, victory and defeat.
    /// All gameplay systems live in their own managers.
    /// </summary>
    [DefaultExecutionOrder(-200)]
    public class GameManager : MonoBehaviour
    {
        [SerializeField] private MatchConfig matchConfig;
        [SerializeField] private PlayerManager playerManager;
        [Tooltip("Optional. Used only to read the Pause action.")]
        [SerializeField] private InputReader input;

        public GameState State { get; private set; } = GameState.None;
        public MatchConfig MatchConfig => matchConfig;
        public bool IsPlaying => State == GameState.Playing;

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
            Time.timeScale = 1f;
        }

        private void Start()
        {
            InitializeMatch();
        }

        private void Update()
        {
            if (input != null && input.isActiveAndEnabled && input.Pause.WasPressedThisFrame())
            {
                TogglePause();
            }
        }

        public void InitializeMatch()
        {
            if (matchConfig == null || playerManager == null)
            {
                Debug.LogError("[GameManager] MatchConfig and PlayerManager must be assigned.", this);
                return;
            }

            SetState(GameState.Initializing);
            playerManager.InitializePlayers(matchConfig);
            Time.timeScale = 1f;
            SetState(GameState.Playing);
        }

        public void TogglePause()
        {
            if (State == GameState.Playing)
            {
                Time.timeScale = 0f;
                SetState(GameState.Paused);
            }
            else if (State == GameState.Paused)
            {
                Time.timeScale = 1f;
                SetState(GameState.Playing);
            }
        }

        /// <summary>Called by the victory rules system (Phase 5+) once a team has won.</summary>
        public void EndMatch(int winningTeam)
        {
            if (State == GameState.Victory || State == GameState.Defeat)
            {
                return;
            }

            PlayerState local = playerManager.LocalPlayer;
            bool localWon = local != null && local.Team == winningTeam;
            SetState(localWon ? GameState.Victory : GameState.Defeat);
            EventBus.Publish(new MatchEndedEvent(winningTeam, localWon));
        }

        private void SetState(GameState next)
        {
            if (State == next)
            {
                return;
            }

            GameState previous = State;
            State = next;
            EventBus.Publish(new GameStateChangedEvent(previous, next));
        }
    }
}
