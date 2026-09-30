using UnityEngine;

namespace AgeOfWorlds.Data
{
    /// <summary>Placeholder for faction-specific content (starting units, unique rosters) in later phases.</summary>
    [CreateAssetMenu(menuName = "Age of Worlds/Faction Data", fileName = "NewFaction")]
    public class FactionData : ScriptableObject
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField, TextArea] private string description;
        [SerializeField] private Sprite icon;

        public string ID => id;
        public string DisplayName => string.IsNullOrEmpty(displayName) ? name : displayName;
        public string Description => description;
        public Sprite Icon => icon;
    }
}
