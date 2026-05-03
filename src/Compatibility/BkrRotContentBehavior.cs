using TaleWorlds.CampaignSystem;
using TaleWorlds.Library;

namespace BannerKingsRedux.RealmOfThrones.Compatibility
{
    public sealed class BkrRotContentBehavior : CampaignBehaviorBase
    {
        private const string Message = "BKR-ROT compatibility behavior loaded.";

        public override void RegisterEvents()
        {
            CampaignEvents.OnSessionLaunchedEvent.AddNonSerializedListener(this, OnSessionLaunched);
        }

        public override void SyncData(IDataStore dataStore)
        {
            // No save data for now.
        }

        private static void OnSessionLaunched(CampaignGameStarter starter)
        {
            InformationManager.DisplayMessage(new InformationMessage(Message));
        }
    }
}
