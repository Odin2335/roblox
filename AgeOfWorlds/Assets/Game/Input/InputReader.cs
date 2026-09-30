using AgeOfWorlds.Core;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;

namespace AgeOfWorlds.InputHandling
{
    /// <summary>
    /// Single access point to the RTSControls input actions. Gameplay code reads
    /// actions by meaning (Select, Command, Stop), never by physical key,
    /// so all bindings stay configurable in the .inputactions asset.
    /// </summary>
    [DefaultExecutionOrder(-190)]
    public class InputReader : MonoBehaviour
    {
        public const int ControlGroupCount = 9;

        [SerializeField] private InputActionAsset actions;
        [SerializeField] private string gameplayMapName = "Gameplay";

        private InputActionMap gameplayMap;

        // Pointer & selection
        public InputAction PointerPosition { get; private set; }
        public InputAction Select { get; private set; }
        public InputAction Command { get; private set; }
        public InputAction AdditiveModifier { get; private set; }

        // Camera (WASD + arrows are camera-only)
        public InputAction CameraMove { get; private set; }
        public InputAction CameraZoom { get; private set; }
        public InputAction CameraRotate { get; private set; }
        public InputAction CameraDrag { get; private set; }

        // Match
        public InputAction Pause { get; private set; }
        public InputAction Cancel { get; private set; }

        // Unit commands
        public InputAction CycleFormation { get; private set; }
        public InputAction AttackMove { get; private set; }
        public InputAction Stop { get; private set; }
        public InputAction HoldPosition { get; private set; }
        public InputAction Patrol { get; private set; }
        public InputAction BuildMenu { get; private set; }
        public InputAction Repair { get; private set; }

        // Control groups: modifier + ControlGroups[0..8] (bound to 1-9 by default)
        public InputAction ControlGroupAssignModifier { get; private set; }
        public InputAction[] ControlGroups { get; } = new InputAction[ControlGroupCount];

        public Vector2 PointerScreenPosition => PointerPosition.ReadValue<Vector2>();
        public bool IsAdditiveHeld => AdditiveModifier.IsPressed();

        /// <summary>True when the pointer is over a UI element (requires an EventSystem in the scene).</summary>
        public bool IsPointerOverUI => EventSystem.current != null && EventSystem.current.IsPointerOverGameObject();

        private void Awake()
        {
            if (actions == null)
            {
                Debug.LogError("[InputReader] Assign the RTSControls input actions asset.", this);
                enabled = false;
                return;
            }

            gameplayMap = actions.FindActionMap(gameplayMapName, true);
            PointerPosition = Find("PointerPosition");
            Select = Find("Select");
            Command = Find("Command");
            AdditiveModifier = Find("AdditiveModifier");
            CameraMove = Find("CameraMove");
            CameraZoom = Find("CameraZoom");
            CameraRotate = Find("CameraRotate");
            CameraDrag = Find("CameraDrag");
            Pause = Find("Pause");
            Cancel = Find("Cancel");
            CycleFormation = Find("CycleFormation");
            AttackMove = Find("AttackMove");
            Stop = Find("Stop");
            HoldPosition = Find("HoldPosition");
            Patrol = Find("Patrol");
            BuildMenu = Find("BuildMenu");
            Repair = Find("Repair");
            ControlGroupAssignModifier = Find("ControlGroupAssignModifier");
            for (int i = 0; i < ControlGroupCount; i++)
            {
                ControlGroups[i] = Find($"ControlGroup{i + 1}");
            }

            GameServices.Register(this);
        }

        private InputAction Find(string actionName) => gameplayMap.FindAction(actionName, true);

        private void OnEnable()
        {
            gameplayMap?.Enable();
        }

        private void OnDisable()
        {
            gameplayMap?.Disable();
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }
    }
}
