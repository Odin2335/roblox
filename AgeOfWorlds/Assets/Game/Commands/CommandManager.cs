using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.InputHandling;
using AgeOfWorlds.Selection;
using AgeOfWorlds.Units;
using UnityEngine;

namespace AgeOfWorlds.Commands
{
    /// <summary>
    /// Turns player input into unit commands. The public Issue* methods are input-independent
    /// so the AI can reuse the same command path.
    /// </summary>
    public class CommandManager : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private InputReader input;
        [SerializeField] private SelectionManager selection;
        [SerializeField] private Camera worldCamera;

        [Header("Raycasts")]
        [Tooltip("Layers that count as walkable ground for move commands.")]
        [SerializeField] private LayerMask groundMask = 1;
        [SerializeField] private float maxRayDistance = 1000f;

        [Header("Formations")]
        [SerializeField] private FormationType formation = FormationType.Loose;
        [Tooltip("Extra gap between units on top of their diameters.")]
        [SerializeField] private float formationGap = 0.6f;

        private readonly List<Unit> commandBuffer = new List<Unit>();
        private readonly List<Vector3> destinationBuffer = new List<Vector3>();
        private GameManager gameManager;

        public FormationType Formation => formation;

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        private void Start()
        {
            gameManager = GameServices.Get<GameManager>();
            if (worldCamera == null)
            {
                worldCamera = Camera.main;
            }
        }

        private void Update()
        {
            if (input == null || selection == null || (gameManager != null && !gameManager.IsPlaying))
            {
                return;
            }

            if (input.CycleFormation.WasPressedThisFrame())
            {
                CycleFormation();
            }

            if (input.Command.WasPressedThisFrame() && !input.IsPointerOverUI)
            {
                HandleContextCommand();
            }
        }

        public void CycleFormation()
        {
            formation = (FormationType)(((int)formation + 1) % System.Enum.GetValues(typeof(FormationType)).Length);
            EventBus.Publish(new FormationChangedEvent(formation));
            Debug.Log($"[CommandManager] Formation: {formation}");
        }

        public void IssueMove(IReadOnlyList<Unit> units, Vector3 destination)
        {
            if (units.Count == 0)
            {
                return;
            }

            if (units.Count == 1)
            {
                units[0].ExecuteCommand(UnitCommand.Move(destination));
                return;
            }

            float largestRadius = 0f;
            for (int i = 0; i < units.Count; i++)
            {
                largestRadius = Mathf.Max(largestRadius, units[i].Movement.Radius);
            }

            FormationUtility.ComputeDestinations(units, destination, formation, largestRadius * 2f + formationGap, destinationBuffer);
            for (int i = 0; i < units.Count; i++)
            {
                units[i].ExecuteCommand(UnitCommand.Move(destinationBuffer[i]));
            }
        }

        public void IssueStop(IReadOnlyList<Unit> units)
        {
            for (int i = 0; i < units.Count; i++)
            {
                units[i].ExecuteCommand(UnitCommand.Stop());
            }
        }

        /// <summary>Right-click. Phase 1: move only. Later: attack, gather, build, repair by target type.</summary>
        private void HandleContextCommand()
        {
            commandBuffer.Clear();
            selection.GetCommandableUnits(commandBuffer);
            if (commandBuffer.Count == 0 || worldCamera == null)
            {
                return;
            }

            Ray ray = worldCamera.ScreenPointToRay(input.PointerScreenPosition);
            if (Physics.Raycast(ray, out RaycastHit hit, maxRayDistance, groundMask, QueryTriggerInteraction.Ignore))
            {
                IssueMove(commandBuffer, hit.point);
            }
        }
    }
}
