using AgeOfWorlds.Core;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;

namespace AgeOfWorlds.InputHandling
{
    /// <summary>
    /// Single access point to the RTSControls input actions. Gameplay code reads
    /// actions by meaning (Select, Command, CameraMove), never by physical key,
    /// so all bindings stay configurable in the .inputactions asset.
    /// </summary>
    [DefaultExecutionOrder(-190)]
    public class InputReader : MonoBehaviour
    {
        [SerializeField] private InputActionAsset actions;
        [SerializeField] private string gameplayMapName = "Gameplay";

        private InputActionMap gameplayMap;

        public InputAction PointerPosition { get; private set; }
        public InputAction Select { get; private set; }
        public InputAction Command { get; private set; }
        public InputAction AdditiveModifier { get; private set; }
        public InputAction CameraMove { get; private set; }
        public InputAction CameraZoom { get; private set; }
        public InputAction CameraRotate { get; private set; }
        public InputAction CameraDrag { get; private set; }
        public InputAction CycleFormation { get; private set; }
        public InputAction Pause { get; private set; }

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
            PointerPosition = gameplayMap.FindAction("PointerPosition", true);
            Select = gameplayMap.FindAction("Select", true);
            Command = gameplayMap.FindAction("Command", true);
            AdditiveModifier = gameplayMap.FindAction("AdditiveModifier", true);
            CameraMove = gameplayMap.FindAction("CameraMove", true);
            CameraZoom = gameplayMap.FindAction("CameraZoom", true);
            CameraRotate = gameplayMap.FindAction("CameraRotate", true);
            CameraDrag = gameplayMap.FindAction("CameraDrag", true);
            CycleFormation = gameplayMap.FindAction("CycleFormation", true);
            Pause = gameplayMap.FindAction("Pause", true);

            GameServices.Register(this);
        }

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
