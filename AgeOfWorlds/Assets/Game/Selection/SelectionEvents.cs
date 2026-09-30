using System.Collections.Generic;
using AgeOfWorlds.Core;

namespace AgeOfWorlds.Selection
{
    public readonly struct SelectionChangedEvent
    {
        public readonly IReadOnlyList<ISelectable> Selected;
        public SelectionChangedEvent(IReadOnlyList<ISelectable> selected) => Selected = selected;
    }
}
