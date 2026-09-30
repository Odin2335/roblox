using UnityEngine;

namespace AgeOfWorlds.Core
{
    /// <summary>
    /// Playable map area on the XZ plane, centered on this transform.
    /// Used by the camera now and later by building placement, fog of war and minimap.
    /// </summary>
    [DefaultExecutionOrder(-200)]
    public class MapBounds : MonoBehaviour
    {
        [SerializeField] private Vector2 size = new Vector2(200f, 200f);

        public Vector2 Size => size;
        public Vector3 Center => transform.position;
        public Vector2 Min => new Vector2(Center.x - size.x * 0.5f, Center.z - size.y * 0.5f);
        public Vector2 Max => new Vector2(Center.x + size.x * 0.5f, Center.z + size.y * 0.5f);

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public bool Contains(Vector3 position)
        {
            Vector2 min = Min;
            Vector2 max = Max;
            return position.x >= min.x && position.x <= max.x && position.z >= min.y && position.z <= max.y;
        }

        public Vector3 Clamp(Vector3 position, float margin = 0f)
        {
            Vector2 min = Min;
            Vector2 max = Max;
            position.x = Mathf.Clamp(position.x, min.x + margin, max.x - margin);
            position.z = Mathf.Clamp(position.z, min.y + margin, max.y - margin);
            return position;
        }

        private void OnDrawGizmos()
        {
            Gizmos.color = Color.cyan;
            Gizmos.DrawWireCube(transform.position, new Vector3(size.x, 0.1f, size.y));
        }
    }
}
