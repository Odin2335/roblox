using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Economy;
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
        [Tooltip("Layers of right-click targets: resource nodes, drop-off buildings (later enemies, construction sites).")]
        [SerializeField] private LayerMask interactableMask;
        [SerializeField] private float maxRayDistance = 1000f;

        [Header("Formations")]
        [SerializeField] private FormationType formation = FormationType.Loose;
        [Tooltip("Extra gap between units on top of their diameters.")]
        [SerializeField] private float formationGap = 0.6f;

        private readonly List<Unit> commandBuffer = new List<Unit>();
        private readonly List<Unit> workerBuffer = new List<Unit>();
        private readonly List<Unit> otherBuffer = new List<Unit>();
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

            if (input.Stop.WasPressedThisFrame())
            {
                commandBuffer.Clear();
                selection.GetCommandableUnits(commandBuffer);
                IssueStop(commandBuffer);
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

        /// <summary>Workers gather the node; other units walk next to it.</summary>
        public void IssueGather(IReadOnlyList<Unit> units, ResourceNode node)
        {
            workerBuffer.Clear();
            otherBuffer.Clear();
            for (int i = 0; i < units.Count; i++)
            {
                (units[i].Worker != null ? workerBuffer : otherBuffer).Add(units[i]);
            }

            for (int i = 0; i < workerBuffer.Count; i++)
            {
                workerBuffer[i].ExecuteCommand(UnitCommand.Gather(node));
            }

            if (otherBuffer.Count > 0)
            {
                IssueMove(otherBuffer, node.transform.position);
            }
        }

        /// <summary>Workers carrying resources deliver them to this drop-off; everyone else moves there.</summary>
        public void IssueReturnResources(IReadOnlyList<Unit> units, ResourceDropOff dropOff)
        {
            otherBuffer.Clear();
            for (int i = 0; i < units.Count; i++)
            {
                Unit unit = units[i];
                if (unit.Worker != null && unit.Worker.IsCarrying && dropOff.Accepts(unit.Worker.CarriedResourceType))
                {
                    unit.ExecuteCommand(UnitCommand.ReturnResource(dropOff));
                }
                else
                {
                    otherBuffer.Add(unit);
                }
            }

            if (otherBuffer.Count > 0)
            {
                IssueMove(otherBuffer, dropOff.GetClosestPoint(otherBuffer[0].transform.position));
            }
        }

        public void IssueStop(IReadOnlyList<Unit> units)
        {
            for (int i = 0; i < units.Count; i++)
            {
                units[i].ExecuteCommand(UnitCommand.Stop());
            }
        }

        /// <summary>Right-click: gather on resource nodes, deliver at own drop-offs, otherwise move. Later: attack, build, repair.</summary>
        private void HandleContextCommand()
        {
            commandBuffer.Clear();
            selection.GetCommandableUnits(commandBuffer);
            if (commandBuffer.Count == 0 || worldCamera == null)
            {
                return;
            }

            Ray ray = worldCamera.ScreenPointToRay(input.PointerScreenPosition);
            if (!Physics.Raycast(ray, out RaycastHit hit, maxRayDistance, groundMask | interactableMask, QueryTriggerInteraction.Ignore))
            {
                return;
            }

            ResourceNode node = hit.collider.GetComponentInParent<ResourceNode>();
            if (node != null && !node.IsDepleted)
            {
                IssueGather(commandBuffer, node);
                return;
            }

            ResourceDropOff dropOff = hit.collider.GetComponentInParent<ResourceDropOff>();
            if (dropOff != null && dropOff.OwnerId == commandBuffer[0].OwnerId)
            {
                IssueReturnResources(commandBuffer, dropOff);
                return;
            }

            IssueMove(commandBuffer, hit.point);
        }
    }
}
