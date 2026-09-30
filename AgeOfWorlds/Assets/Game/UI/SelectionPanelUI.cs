using AgeOfWorlds.Core;
using AgeOfWorlds.Selection;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace AgeOfWorlds.UserInterface
{
    /// <summary>
    /// Bottom-center info panel: icon, name and HP of the selection.
    /// Reacts to SelectionChangedEvent; HP is refreshed at a low rate until damage events exist.
    /// Command buttons are added in later phases.
    /// </summary>
    public class SelectionPanelUI : MonoBehaviour
    {
        [SerializeField] private GameObject panelRoot;
        [SerializeField] private Image iconImage;
        [SerializeField] private TMP_Text nameText;
        [SerializeField] private TMP_Text healthText;
        [SerializeField] private float refreshInterval = 0.25f;

        private SelectionManager selectionManager;
        private float refreshTimer;

        private void OnEnable()
        {
            EventBus.Subscribe<SelectionChangedEvent>(OnSelectionChanged);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<SelectionChangedEvent>(OnSelectionChanged);
        }

        private void Start()
        {
            if (panelRoot == gameObject)
            {
                Debug.LogError("[SelectionPanelUI] panelRoot must be a child object, not the object holding this script.", this);
                panelRoot = null;
            }

            selectionManager = GameServices.Get<SelectionManager>();
            Refresh();
        }

        private void Update()
        {
            refreshTimer += Time.unscaledDeltaTime;
            if (refreshTimer >= refreshInterval)
            {
                refreshTimer = 0f;
                Refresh();
            }
        }

        private void OnSelectionChanged(SelectionChangedEvent evt)
        {
            Refresh();
        }

        private void Refresh()
        {
            int count = selectionManager != null ? selectionManager.Selected.Count : 0;
            if (panelRoot != null)
            {
                panelRoot.SetActive(count > 0);
            }

            if (count == 0)
            {
                return;
            }

            ISelectable first = selectionManager.Selected[0];

            if (iconImage != null)
            {
                iconImage.sprite = first.Icon;
                iconImage.enabled = first.Icon != null;
            }

            if (nameText != null)
            {
                nameText.text = count == 1 ? first.DisplayName : $"{first.DisplayName} (+{count - 1})";
            }

            if (healthText != null)
            {
                healthText.text = count == 1
                    ? $"HP {Mathf.CeilToInt(first.CurrentHealth)} / {Mathf.CeilToInt(first.MaxHealth)}"
                    : $"{count} selected";
            }
        }
    }
}
