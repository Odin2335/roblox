using UnityEngine;
using UnityEngine.UI;

namespace AgeOfWorlds.UserInterface
{
    /// <summary>
    /// Draws the drag-selection rectangle. Put this on a UI Image inside a
    /// Screen Space - Overlay canvas. Anchors and pivot are configured automatically.
    /// Leave the GameObject active; visibility is toggled on the Graphic.
    /// </summary>
    [RequireComponent(typeof(RectTransform), typeof(Graphic))]
    public class SelectionBoxUI : MonoBehaviour
    {
        private RectTransform rectTransform;
        private RectTransform parentRect;
        private Graphic graphic;

        private void Awake()
        {
            rectTransform = (RectTransform)transform;
            parentRect = rectTransform.parent as RectTransform;
            graphic = GetComponent<Graphic>();
            graphic.raycastTarget = false;
            rectTransform.anchorMin = rectTransform.anchorMax = new Vector2(0.5f, 0.5f);
            rectTransform.pivot = Vector2.zero;
            graphic.enabled = false;
        }

        public void Show(Vector2 screenStart, Vector2 screenEnd)
        {
            if (parentRect == null)
            {
                return;
            }

            // Overlay canvas: no camera needed for the conversion.
            RectTransformUtility.ScreenPointToLocalPointInRectangle(parentRect, screenStart, null, out Vector2 a);
            RectTransformUtility.ScreenPointToLocalPointInRectangle(parentRect, screenEnd, null, out Vector2 b);

            Vector2 min = Vector2.Min(a, b);
            Vector2 max = Vector2.Max(a, b);
            rectTransform.localPosition = min;
            rectTransform.sizeDelta = max - min;
            graphic.enabled = true;
        }

        public void Hide()
        {
            if (graphic != null)
            {
                graphic.enabled = false;
            }
        }
    }
}
