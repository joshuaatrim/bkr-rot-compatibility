// SPDX-License-Identifier: MIT

using TaleWorlds.Library;
using TaleWorlds.MountAndBlade;

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
    }
}
