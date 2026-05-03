// SPDX-License-Identifier: MIT

using TaleWorlds.Library;
using TaleWorlds.MountAndBlade;
using BannerKingsRedux.RealmOfThrones.Compatibility;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BannerKingsRedux.RealmOfThrones
{
    public class SubModule : MBSubModuleBase
    {
        protected override void OnSubModuleLoad()
        {
            base.OnSubModuleLoad();

            InformationManager.DisplayMessage(
                new InformationMessage("[BKR-ROT] Compatibility patch loaded.")
            );
        }

        protected override void OnBeforeInitialModuleScreenSetAsRoot()
        {
            base.OnBeforeInitialModuleScreenSetAsRoot();

            InformationManager.DisplayMessage(
                new InformationMessage("[BKR-ROT] Milestone 1 empty module initialized.")
            );
        }

        protected override void OnGameStart(Game game, IGameStarter gameStarterObject)
        {
            base.OnGameStart(game, gameStarterObject);

            if (game.GameType is Campaign && gameStarterObject is CampaignGameStarter campaignStarter)
            {
                campaignStarter.AddBehavior(new BkrRotContentBehavior());
            }
        }
    }
}
