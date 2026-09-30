using AgeOfWorlds.Core;
using AgeOfWorlds.InputHandling;
using UnityEngine;

namespace AgeOfWorlds.CameraSystem
{
    /// <summary>
    /// Classic RTS camera rig. This transform is the ground focus point (position + yaw);
    /// the child camera is placed behind it based on zoom (distance + pitch).
    /// Uses unscaled time so the camera still works while the game is paused.
    /// </summary>
    public class RTSCameraController : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private InputReader input;
        [SerializeField] private Transform cameraTransform;
        [Tooltip("Optional. If empty, the MapBounds registered in the scene is used.")]
        [SerializeField] private MapBounds mapBounds;

        [Header("Panning")]
        [SerializeField] private float panSpeedZoomedIn = 20f;
        [SerializeField] private float panSpeedZoomedOut = 70f;
        [Tooltip("Higher = snappier acceleration and deceleration.")]
        [SerializeField] private float panSmoothing = 10f;
        [SerializeField] private bool edgeScrolling = true;
        [SerializeField] private float edgeScrollBorder = 12f;
        [SerializeField] private bool middleMouseDrag = true;
        [SerializeField] private float dragSensitivity = 1f;

        [Header("Zoom")]
        [Tooltip("Close combat view distance.")]
        [SerializeField] private float minDistance = 12f;
        [Tooltip("Strategic far view distance.")]
        [SerializeField] private float maxDistance = 75f;
        [SerializeField] private float minPitch = 40f;
        [SerializeField] private float maxPitch = 65f;
        [Tooltip("Zoom change per scroll notch, in 0..1 zoom space.")]
        [SerializeField] private float zoomStep = 0.08f;
        [SerializeField] private float zoomSmoothing = 10f;
        [SerializeField, Range(0f, 1f)] private float initialZoom = 0.45f;

        [Header("Rotation")]
        [SerializeField] private bool allowRotation = true;
        [SerializeField] private float rotationSpeed = 90f;

        private Vector3 panVelocity;
        private float zoom;
        private float targetZoom;
        private float yaw;
        private Vector2 lastPointerPosition;

        private void Start()
        {
            if (mapBounds == null)
            {
                mapBounds = GameServices.Get<MapBounds>();
            }

            if (cameraTransform == null && Camera.main != null)
            {
                cameraTransform = Camera.main.transform;
            }

            zoom = targetZoom = initialZoom;
            yaw = transform.eulerAngles.y;
            ApplyTransform();
        }

        private void LateUpdate()
        {
            if (input == null || cameraTransform == null)
            {
                return;
            }

            float deltaTime = Time.unscaledDeltaTime;
            UpdatePan(deltaTime);
            UpdateDrag();
            UpdateZoom(deltaTime);
            UpdateRotation(deltaTime);
            ApplyTransform();
        }

        /// <summary>Instantly centers the camera on a world position (control groups, notifications, minimap).</summary>
        public void FocusOn(Vector3 worldPosition)
        {
            transform.position = new Vector3(worldPosition.x, transform.position.y, worldPosition.z);
            panVelocity = Vector3.zero;
            ApplyTransform();
        }

        private void UpdatePan(float deltaTime)
        {
            Vector2 direction = input.CameraMove.ReadValue<Vector2>();

            if (edgeScrolling && Application.isFocused)
            {
                direction += GetEdgeScrollDirection(input.PointerScreenPosition);
            }

            direction = Vector2.ClampMagnitude(direction, 1f);
            Quaternion yawRotation = Quaternion.Euler(0f, yaw, 0f);
            Vector3 worldDirection = yawRotation * new Vector3(direction.x, 0f, direction.y);
            float speed = Mathf.Lerp(panSpeedZoomedIn, panSpeedZoomedOut, zoom);

            float blend = 1f - Mathf.Exp(-panSmoothing * deltaTime);
            panVelocity = Vector3.Lerp(panVelocity, worldDirection * speed, blend);
            transform.position += panVelocity * deltaTime;
        }

        private Vector2 GetEdgeScrollDirection(Vector2 pointer)
        {
            // Ignore the pointer when it is outside the game window.
            if (pointer.x < 0f || pointer.y < 0f || pointer.x > Screen.width || pointer.y > Screen.height)
            {
                return Vector2.zero;
            }

            Vector2 direction = Vector2.zero;
            if (pointer.x <= edgeScrollBorder) direction.x -= 1f;
            else if (pointer.x >= Screen.width - edgeScrollBorder) direction.x += 1f;
            if (pointer.y <= edgeScrollBorder) direction.y -= 1f;
            else if (pointer.y >= Screen.height - edgeScrollBorder) direction.y += 1f;
            return direction;
        }

        private void UpdateDrag()
        {
            Vector2 pointer = input.PointerScreenPosition;
            if (middleMouseDrag && input.CameraDrag.IsPressed() && !input.CameraDrag.WasPressedThisFrame())
            {
                Vector2 delta = pointer - lastPointerPosition;
                float worldPerPixel = CurrentDistance() * 2f / Mathf.Max(1, Screen.height) * dragSensitivity;
                Vector3 move = Quaternion.Euler(0f, yaw, 0f) * new Vector3(-delta.x, 0f, -delta.y) * worldPerPixel;
                transform.position += move;
                panVelocity = Vector3.zero;
            }

            lastPointerPosition = pointer;
        }

        private void UpdateZoom(float deltaTime)
        {
            float scroll = input.CameraZoom.ReadValue<float>();
            if (Mathf.Abs(scroll) > 0.01f)
            {
                // Scroll values differ per platform, so only the direction is used.
                targetZoom = Mathf.Clamp01(targetZoom - Mathf.Sign(scroll) * zoomStep);
            }

            zoom = Mathf.Lerp(zoom, targetZoom, 1f - Mathf.Exp(-zoomSmoothing * deltaTime));
        }

        private void UpdateRotation(float deltaTime)
        {
            if (!allowRotation)
            {
                return;
            }

            yaw += input.CameraRotate.ReadValue<float>() * rotationSpeed * deltaTime;
        }

        private float CurrentDistance() => Mathf.Lerp(minDistance, maxDistance, zoom);

        private void ApplyTransform()
        {
            if (mapBounds != null)
            {
                transform.position = mapBounds.Clamp(transform.position);
            }

            transform.rotation = Quaternion.Euler(0f, yaw, 0f);

            if (cameraTransform == null)
            {
                return;
            }

            Quaternion pitchRotation = Quaternion.Euler(Mathf.Lerp(minPitch, maxPitch, zoom), 0f, 0f);
            cameraTransform.localRotation = pitchRotation;
            cameraTransform.localPosition = pitchRotation * Vector3.back * CurrentDistance();
        }
    }
}
