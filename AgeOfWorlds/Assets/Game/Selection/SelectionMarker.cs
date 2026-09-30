using UnityEngine;

namespace AgeOfWorlds.Selection
{
    /// <summary>
    /// Ground ring under a selected object. Built procedurally with a LineRenderer,
    /// so no prefab is required. Pooled by SelectionManager and positioned each frame
    /// (not parented, which keeps it safe when the target is destroyed).
    /// </summary>
    [RequireComponent(typeof(LineRenderer))]
    public class SelectionMarker : MonoBehaviour
    {
        private const int Segments = 32;
        private const float HeightOffset = 0.05f;

        private LineRenderer lineRenderer;
        private Transform target;

        public static SelectionMarker Create(Material material, Transform parent)
        {
            var go = new GameObject("SelectionMarker");
            go.transform.SetParent(parent, false);
            var line = go.AddComponent<LineRenderer>();
            line.useWorldSpace = false;
            line.loop = true;
            line.positionCount = Segments;
            line.widthMultiplier = 0.08f;
            line.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            line.receiveShadows = false;
            line.sharedMaterial = material;
            return go.AddComponent<SelectionMarker>();
        }

        private void Awake()
        {
            lineRenderer = GetComponent<LineRenderer>();
        }

        public void Attach(Transform followTarget, float radius, Color color)
        {
            target = followTarget;
            lineRenderer.startColor = color;
            lineRenderer.endColor = color;

            float ringRadius = radius * 1.15f;
            for (int i = 0; i < Segments; i++)
            {
                float angle = i / (float)Segments * Mathf.PI * 2f;
                lineRenderer.SetPosition(i, new Vector3(Mathf.Cos(angle) * ringRadius, 0f, Mathf.Sin(angle) * ringRadius));
            }

            Follow();
        }

        public void Detach()
        {
            target = null;
        }

        public void Follow()
        {
            if (target != null)
            {
                transform.position = target.position + Vector3.up * HeightOffset;
            }
        }
    }
}
