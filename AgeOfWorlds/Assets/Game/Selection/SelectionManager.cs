using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Core.Players;
using AgeOfWorlds.Economy;
using AgeOfWorlds.InputHandling;
using AgeOfWorlds.Units;
using AgeOfWorlds.UserInterface;
using UnityEngine;
using UnityEngine.Pool;

namespace AgeOfWorlds.Selection
{
    /// <summary>
    /// Classic RTS selection: click, drag box, Shift add/remove, double-click same type.
    /// Box selection only picks the local player's units; a single click may inspect anything.
    /// </summary>
    public class SelectionManager : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private InputReader input;
        [SerializeField] private Camera worldCamera;
        [SerializeField] private SelectionBoxUI selectionBox;

        [Header("Picking")]
        [Tooltip("Layers containing selectable colliders (units, later buildings).")]
        [SerializeField] private LayerMask selectableMask = ~0;
        [SerializeField] private float maxRayDistance = 1000f;
        [Tooltip("Pixels the mouse must travel before a click becomes a box selection.")]
        [SerializeField] private float dragThreshold = 8f;
        [SerializeField] private float doubleClickTime = 0.3f;

        [Header("Markers")]
        [Tooltip("Optional. Defaults to the built-in Sprites/Default shader.")]
        [SerializeField] private Material markerMaterial;
        [SerializeField] private Color ownColor = new Color(0.3f, 1f, 0.3f);
        [SerializeField] private Color allyColor = new Color(0.3f, 0.8f, 1f);
        [SerializeField] private Color enemyColor = new Color(1f, 0.3f, 0.25f);
        [SerializeField] private Color neutralColor = new Color(1f, 0.9f, 0.3f);

        private readonly List<ISelectable> selected = new List<ISelectable>();
        private readonly Dictionary<ISelectable, SelectionMarker> markers = new Dictionary<ISelectable, SelectionMarker>();
        private ObjectPool<SelectionMarker> markerPool;
        private Transform markerRoot;

        private UnitManager unitManager;
        private PlayerManager playerManager;
        private GameManager gameManager;

        private bool pointerDown;
        private bool dragging;
        private Vector2 dragStart;
        private ISelectable lastClicked;
        private float lastClickTime = -10f;

        public IReadOnlyList<ISelectable> Selected => selected;
        private int LocalPlayerId => playerManager != null ? playerManager.LocalPlayerId : 0;

        private void Awake()
        {
            GameServices.Register(this);

            if (markerMaterial == null)
            {
                markerMaterial = new Material(Shader.Find("Sprites/Default"));
            }

            markerRoot = new GameObject("SelectionMarkers").transform;
            markerPool = new ObjectPool<SelectionMarker>(
                createFunc: () => SelectionMarker.Create(markerMaterial, markerRoot),
                actionOnGet: marker => marker.gameObject.SetActive(true),
                actionOnRelease: marker =>
                {
                    if (marker == null)
                    {
                        return; // Destroyed during scene unload.
                    }

                    marker.Detach();
                    marker.gameObject.SetActive(false);
                },
                actionOnDestroy: marker =>
                {
                    if (marker != null)
                    {
                        Destroy(marker.gameObject);
                    }
                },
                collectionCheck: false,
                defaultCapacity: 32);
        }

        private void OnEnable()
        {
            EventBus.Subscribe<UnitRemovedEvent>(OnUnitRemoved);
            EventBus.Subscribe<ResourceNodeDepletedEvent>(OnResourceNodeDepleted);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<UnitRemovedEvent>(OnUnitRemoved);
            EventBus.Unsubscribe<ResourceNodeDepletedEvent>(OnResourceNodeDepleted);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        private void Start()
        {
            unitManager = GameServices.Get<UnitManager>();
            playerManager = GameServices.Get<PlayerManager>();
            gameManager = GameServices.Get<GameManager>();
            if (worldCamera == null)
            {
                worldCamera = Camera.main;
            }
        }

        private void Update()
        {
            if (input == null || worldCamera == null || (gameManager != null && !gameManager.IsPlaying))
            {
                CancelDrag();
                return;
            }

            HandlePointer();
        }

        private void LateUpdate()
        {
            foreach (SelectionMarker marker in markers.Values)
            {
                marker.Follow();
            }
        }

        // ---------- Public API ----------

        /// <summary>Adds the local player's selected, living units to results (what commands apply to).</summary>
        public void GetCommandableUnits(List<Unit> results)
        {
            int localId = LocalPlayerId;
            for (int i = 0; i < selected.Count; i++)
            {
                if (selected[i] is Unit unit && unit.OwnerId == localId && unit.IsAlive)
                {
                    results.Add(unit);
                }
            }
        }

        public void SetSelection(IReadOnlyList<ISelectable> items)
        {
            ClearInternal();
            for (int i = 0; i < items.Count; i++)
            {
                AddInternal(items[i]);
            }

            PublishChanged();
        }

        public void ClearSelection()
        {
            if (selected.Count == 0)
            {
                return;
            }

            ClearInternal();
            PublishChanged();
        }

        // ---------- Input ----------

        private void HandlePointer()
        {
            Vector2 pointer = input.PointerScreenPosition;

            if (input.Select.WasPressedThisFrame() && !input.IsPointerOverUI)
            {
                pointerDown = true;
                dragging = false;
                dragStart = pointer;
            }

            if (pointerDown && !dragging && (pointer - dragStart).sqrMagnitude > dragThreshold * dragThreshold)
            {
                dragging = true;
            }

            if (dragging && selectionBox != null)
            {
                selectionBox.Show(dragStart, pointer);
            }

            if (pointerDown && input.Select.WasReleasedThisFrame())
            {
                bool additive = input.IsAdditiveHeld;
                if (dragging)
                {
                    BoxSelect(dragStart, pointer, additive);
                }
                else
                {
                    ClickSelect(pointer, additive);
                }

                CancelDrag();
            }
        }

        private void CancelDrag()
        {
            pointerDown = false;
            dragging = false;
            if (selectionBox != null)
            {
                selectionBox.Hide();
            }
        }

        private void ClickSelect(Vector2 screenPosition, bool additive)
        {
            ISelectable target = RaycastSelectable(screenPosition);
            bool isDoubleClick = target != null && target == lastClicked && Time.unscaledTime - lastClickTime <= doubleClickTime;
            lastClicked = target;
            lastClickTime = Time.unscaledTime;

            if (target == null)
            {
                if (!additive)
                {
                    ClearSelection();
                }

                return;
            }

            if (isDoubleClick && target is Unit clickedUnit)
            {
                SelectSameTypeOnScreen(clickedUnit, additive);
                return;
            }

            bool isOwn = target.OwnerId == LocalPlayerId;
            if (additive && isOwn && SelectionIsOwnedByLocalPlayer())
            {
                if (selected.Contains(target))
                {
                    RemoveInternal(target);
                }
                else
                {
                    AddInternal(target);
                }
            }
            else
            {
                ClearInternal();
                AddInternal(target);
            }

            PublishChanged();
        }

        private void BoxSelect(Vector2 start, Vector2 end, bool additive)
        {
            Rect rect = Rect.MinMaxRect(
                Mathf.Min(start.x, end.x), Mathf.Min(start.y, end.y),
                Mathf.Max(start.x, end.x), Mathf.Max(start.y, end.y));

            if (!additive || !SelectionIsOwnedByLocalPlayer())
            {
                ClearInternal();
            }

            if (unitManager != null)
            {
                int localId = LocalPlayerId;
                IReadOnlyList<Unit> units = unitManager.Units;
                for (int i = 0; i < units.Count; i++)
                {
                    Unit unit = units[i];
                    if (unit.OwnerId == localId && unit.IsSelectable && IsOnScreenRect(unit.transform.position, rect))
                    {
                        AddInternal(unit);
                    }
                }
            }

            PublishChanged();
        }

        private void SelectSameTypeOnScreen(Unit reference, bool additive)
        {
            if (unitManager == null)
            {
                return;
            }

            if (!additive)
            {
                ClearInternal();
            }

            Rect screen = new Rect(0f, 0f, Screen.width, Screen.height);
            IReadOnlyList<Unit> units = unitManager.Units;
            for (int i = 0; i < units.Count; i++)
            {
                Unit unit = units[i];
                if (unit.Data == reference.Data && unit.OwnerId == reference.OwnerId && unit.IsSelectable &&
                    IsOnScreenRect(unit.transform.position, screen))
                {
                    AddInternal(unit);
                }
            }

            PublishChanged();
        }

        // ---------- Helpers ----------

        private ISelectable RaycastSelectable(Vector2 screenPosition)
        {
            Ray ray = worldCamera.ScreenPointToRay(screenPosition);
            if (!Physics.Raycast(ray, out RaycastHit hit, maxRayDistance, selectableMask, QueryTriggerInteraction.Collide))
            {
                return null;
            }

            ISelectable selectable = hit.collider.GetComponentInParent<ISelectable>();
            return selectable != null && selectable.IsSelectable ? selectable : null;
        }

        private bool IsOnScreenRect(Vector3 worldPosition, Rect rect)
        {
            Vector3 screen = worldCamera.WorldToScreenPoint(worldPosition);
            return screen.z > 0f && rect.Contains(new Vector2(screen.x, screen.y));
        }

        private bool SelectionIsOwnedByLocalPlayer()
        {
            return selected.Count == 0 || selected[0].OwnerId == LocalPlayerId;
        }

        private void AddInternal(ISelectable item)
        {
            if (item == null || markers.ContainsKey(item))
            {
                return;
            }

            selected.Add(item);
            SelectionMarker marker = markerPool.Get();
            marker.Attach(item.Transform, item.SelectionRadius, GetColor(item.OwnerId));
            markers.Add(item, marker);
        }

        private void RemoveInternal(ISelectable item)
        {
            if (!markers.TryGetValue(item, out SelectionMarker marker))
            {
                return;
            }

            selected.Remove(item);
            markers.Remove(item);
            markerPool.Release(marker);
        }

        private void ClearInternal()
        {
            foreach (SelectionMarker marker in markers.Values)
            {
                markerPool.Release(marker);
            }

            markers.Clear();
            selected.Clear();
        }

        private Color GetColor(int ownerId)
        {
            if (playerManager == null)
            {
                return ownerId == LocalPlayerId ? ownColor : enemyColor;
            }

            switch (playerManager.GetRelation(LocalPlayerId, ownerId))
            {
                case PlayerRelation.Self: return ownColor;
                case PlayerRelation.Ally: return allyColor;
                case PlayerRelation.Enemy: return enemyColor;
                default: return neutralColor;
            }
        }

        private void OnUnitRemoved(UnitRemovedEvent evt)
        {
            if (markers.ContainsKey(evt.Unit))
            {
                RemoveInternal(evt.Unit);
                PublishChanged();
            }
        }

        private void OnResourceNodeDepleted(ResourceNodeDepletedEvent evt)
        {
            if (markers.ContainsKey(evt.Node))
            {
                RemoveInternal(evt.Node);
                PublishChanged();
            }
        }

        private void PublishChanged()
        {
            EventBus.Publish(new SelectionChangedEvent(selected));
        }
    }
}
