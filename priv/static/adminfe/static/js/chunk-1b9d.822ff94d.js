(window.webpackJsonp=window.webpackJsonp||[]).push([["chunk-1b9d"],{"+/E+":function(e,t,s){"use strict";s("rf4N")},i7Kn:function(e,t,s){"use strict";var r=s("yXPU"),n=s.n(r),i=s("o0o1"),a=s.n(i),o={props:{selectedUsers:{type:Array,default:function(){return[]}}},computed:{isDesktop:function(){return"desktop"===this.$store.state.app.device},showDropdownForMultipleUsers:function(){return this.$props.selectedUsers.length>0},tagPolicyEnabled:function(){return this.$store.state.users.mrfPolicies.includes("Pleroma.Web.ActivityPub.MRF.TagPolicy")}},methods:{mappers:function(){var e=this,t=function(){var t=n()(a.a.mark(function t(s,r){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,r(s);case 2:e.$emit("apply-action");case 3:case"end":return t.stop()}},t)}));return function(e,s){return t.apply(this,arguments)}}();return{grantRight:function(s){return function(){var r=function(){var t=n()(a.a.mark(function t(r){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("AddRight",{users:r,right:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}(),i=e.selectedUsers.filter(function(t){return e.isLocalUser(t)&&!t.roles[s]&&e.$store.state.user.id!==t.id});t(i,r)}},revokeRight:function(s){return function(){var r=function(){var t=n()(a.a.mark(function t(r){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("DeleteRight",{users:r,right:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}(),i=e.selectedUsers.filter(function(t){return e.isLocalUser(t)&&t.roles[s]&&e.$store.state.user.id!==t.id});t(i,r)}},activate:function(){var s=e.selectedUsers.filter(function(t){return t.nickname&&!t.is_active&&e.$store.state.user.id!==t.id});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("ActivateUsers",{users:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())},deactivate:function(){var s=e.selectedUsers.filter(function(t){return t.nickname&&t.is_active&&e.$store.state.user.id!==t.id});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("DeactivateUsers",{users:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())},remove:function(){var s=e.selectedUsers.filter(function(t){return t.nickname&&e.$store.state.user.id!==t.id});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("DeleteUsers",{users:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())},addTag:function(s){return function(){var r=e.selectedUsers.filter(function(t){return"mrf_tag:disable-remote-subscription"===s||"mrf_tag:disable-any-subscription"===s?e.isLocalUser(t)&&!t.tags.includes(s):t.nickname&&!t.tags.includes(s)});t(r,function(){var t=n()(a.a.mark(function t(r){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("AddTag",{users:r,tag:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())}},removeTag:function(s){return n()(a.a.mark(function r(){var i;return a.a.wrap(function(r){for(;;)switch(r.prev=r.next){case 0:i=e.selectedUsers.filter(function(t){return"mrf_tag:disable-remote-subscription"===s||"mrf_tag:disable-any-subscription"===s?e.isLocalUser(t)&&t.tags.includes(s):t.nickname&&t.tags.includes(s)}),t(i,function(){var t=n()(a.a.mark(function t(r){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("RemoveTag",{users:r,tag:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}());case 3:case"end":return r.stop()}},r)}))},requirePasswordReset:function(){var s=e.selectedUsers.filter(function(t){return e.isLocalUser(t)});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("RequirePasswordReset",s);case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())},approveAccounts:function(){var s=e.selectedUsers.filter(function(t){return e.isLocalUser(t)&&!t.is_approved});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("ApproveUsersAccount",{users:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())},confirmAccounts:function(){var s=e.selectedUsers.filter(function(t){return e.isLocalUser(t)&&!t.is_confirmed});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("ConfirmUsersEmail",{users:s});case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())},resendConfirmation:function(){var s=e.selectedUsers.filter(function(t){return e.isLocalUser(t)&&!t.is_confirmed});t(s,function(){var t=n()(a.a.mark(function t(s){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.next=2,e.$store.dispatch("ResendConfirmationEmail",s);case 2:return t.abrupt("return",t.sent);case 3:case"end":return t.stop()}},t)}));return function(e){return t.apply(this,arguments)}}())}}},isPrivileged:function(e,t){var s=this.$store.getters.privileges,r=this.$store.getters.roles;return e.some(function(e){return s.indexOf(e)>=0})||t.some(function(e){return r.indexOf(e)>=0})},enableTagPolicy:function(){var e=this;this.$confirm(this.$t("users.confirmEnablingTagPolicy"),{confirmButtonText:"Yes",cancelButtonText:"Cancel",type:"warning"}).then(function(){e.$message({type:"success",message:e.$t("users.enableTagPolicySuccessMessage")}),e.$store.dispatch("EnableTagPolicy")}).catch(function(){e.$message({type:"info",message:"Canceled"})})},isLocalUser:function(e){return e.nickname&&e.local},grantRightToMultipleUsers:function(e){var t=this.mappers().grantRight;this.confirmMessage(this.$t("users.grantRightConfirmation",{right:e}),t(e))},revokeRightFromMultipleUsers:function(e){var t=this.mappers().revokeRight;this.confirmMessage(this.$t("users.revokeRightConfirmation",{right:e}),t(e))},activateMultipleUsers:function(){var e=this.mappers().activate;this.confirmMessage(this.$t("users.activateMultipleUsersConfirmation"),e)},deactivateMultipleUsers:function(){var e=this.mappers().deactivate;this.confirmMessage(this.$t("users.deactivateMultipleUsersConfirmation"),e)},deleteMultipleUsers:function(){var e=this.mappers().remove;this.confirmMessage(this.$t("users.deleteMultipleUsersConfirmation"),e)},requirePasswordReset:function(){if(this.$store.state.user.nodeInfo.metadata.mailerEnabled){var e=this.mappers().requirePasswordReset;this.confirmMessage(this.$t("users.requirePasswordResetConfirmation"),e)}else this.$alert(this.$t("users.mailerMustBeEnabled"),"Error",{type:"error"})},addTagForMultipleUsers:function(e){var t=this.mappers().addTag;this.confirmMessage(this.$t("users.addTagForMultipleUsersConfirmation"),t(e))},removeTagFromMultipleUsers:function(e){var t=this.mappers().removeTag;this.confirmMessage(this.$t("users.removeTagFromMultipleUsersConfirmation"),t(e))},approveAccountsForMultipleUsers:function(){var e=this.mappers().approveAccounts;this.confirmMessage(this.$t("users.approveAccountsConfirmation"),e)},rejectAccountsForMultipleUsers:function(){var e=this.mappers().remove;this.confirmMessage(this.$t("users.rejectAccountsConfirmation"),e)},confirmAccountsForMultipleUsers:function(){var e=this.mappers().confirmAccounts;this.confirmMessage(this.$t("users.confirmAccountsConfirmation"),e)},resendConfirmationForMultipleUsers:function(){var e=this.mappers().resendConfirmation;this.confirmMessage(this.$t("users.resendEmailConfirmation"),e)},confirmMessage:function(e,t){var s=this;this.$confirm(e,{confirmButtonText:this.$t("users.ok"),cancelButtonText:this.$t("users.cancel"),type:"warning"}).then(function(){t()}).catch(function(){s.$message({type:"info",message:s.$t("users.canceled")})})}}},u=(s("+/E+"),s("KHd+")),c=Object(u.a)(o,function(){var e=this,t=e._self._c;return e.isPrivileged(["users_manage_invites","users_delete","users_manage_activation_state","users_manage_tags"],["admin"])?t("el-dropdown",{staticClass:"multiple-users-menu",attrs:{size:"small",trigger:"click",placement:"bottom-start"}},[e.isDesktop?t("el-button",{staticClass:"actions-button"},[t("span",{staticClass:"actions-button-container"},[t("span",[t("i",{staticClass:"el-icon-edit"}),e._v("\n        "+e._s(e.$t("users.moderateUsers"))+"\n      ")]),e._v(" "),t("i",{staticClass:"el-icon-arrow-down el-icon--right"})])]):e._e(),e._v(" "),e.showDropdownForMultipleUsers?t("el-dropdown-menu",{attrs:{slot:"dropdown"},slot:"dropdown"},[e.isPrivileged([],["admin"])?t("el-dropdown-item",{staticClass:"grant-right-to-multiple-users",nativeOn:{click:function(t){return e.grantRightToMultipleUsers("admin")}}},[e._v("\n      "+e._s(e.$t("users.grantAdmin"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged([],["admin"])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.revokeRightFromMultipleUsers("admin")}}},[e._v("\n      "+e._s(e.$t("users.revokeAdmin"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged([],["admin"])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.grantRightToMultipleUsers("moderator")}}},[e._v("\n      "+e._s(e.$t("users.grantModerator"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged([],["admin"])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.revokeRightFromMultipleUsers("moderator")}}},[e._v("\n      "+e._s(e.$t("users.revokeModerator"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged(["users_manage_invites"],[])?t("el-dropdown-item",{attrs:{divided:""},nativeOn:{click:function(t){return e.approveAccountsForMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.approveAccounts"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged(["users_delete"],[])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.rejectAccountsForMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.rejectAccounts"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged([],["admin"])?t("el-dropdown-item",{attrs:{divided:""},nativeOn:{click:function(t){return e.confirmAccountsForMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.confirmAccounts"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged([],["admin"])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.resendConfirmationForMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.resendConfirmation"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged(["users_manage_activation_state"],[])?t("el-dropdown-item",{attrs:{divided:""},nativeOn:{click:function(t){return e.activateMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.activateAccounts"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged(["users_manage_activation_state"],[])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.deactivateMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.deactivateAccounts"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged(["users_delete"],[])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.deleteMultipleUsers.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.deleteAccounts"))+"\n    ")]):e._e(),e._v(" "),e.isPrivileged([],["admin"])?t("el-dropdown-item",{nativeOn:{click:function(t){return e.requirePasswordReset.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.requirePasswordReset"))+"\n    ")]):e._e(),e._v(" "),e.tagPolicyEnabled&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{staticClass:"no-hover",attrs:{divided:""}},[t("div",{staticClass:"tag-container"},[t("span",{staticClass:"tag-text"},[e._v(e._s(e.$t("users.forceNsfw")))]),e._v(" "),t("el-button-group",{staticClass:"tag-button-group"},[t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.addTagForMultipleUsers("mrf_tag:media-force-nsfw")}}},[e._v("\n            "+e._s(e.$t("users.apply"))+"\n          ")]),e._v(" "),t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.removeTagFromMultipleUsers("mrf_tag:media-force-nsfw")}}},[e._v("\n            "+e._s(e.$t("users.remove"))+"\n          ")])],1)],1)]):e._e(),e._v(" "),e.tagPolicyEnabled&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{staticClass:"no-hover"},[t("div",{staticClass:"tag-container"},[t("span",{staticClass:"tag-text"},[e._v(e._s(e.$t("users.stripMedia")))]),e._v(" "),t("el-button-group",{staticClass:"tag-button-group"},[t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.addTagForMultipleUsers("mrf_tag:media-strip")}}},[e._v("\n            "+e._s(e.$t("users.apply"))+"\n          ")]),e._v(" "),t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.removeTagFromMultipleUsers("mrf_tag:media-strip")}}},[e._v("\n            "+e._s(e.$t("users.remove"))+"\n          ")])],1)],1)]):e._e(),e._v(" "),e.tagPolicyEnabled&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{staticClass:"no-hover"},[t("div",{staticClass:"tag-container"},[t("span",{staticClass:"tag-text"},[e._v(e._s(e.$t("users.forceUnlisted")))]),e._v(" "),t("el-button-group",{staticClass:"tag-button-group"},[t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.addTagForMultipleUsers("mrf_tag:force-unlisted")}}},[e._v("\n            "+e._s(e.$t("users.apply"))+"\n          ")]),e._v(" "),t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.removeTagFromMultipleUsers("mrf_tag:force-unlisted")}}},[e._v("\n            "+e._s(e.$t("users.remove"))+"\n          ")])],1)],1)]):e._e(),e._v(" "),e.tagPolicyEnabled&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{staticClass:"no-hover"},[t("div",{staticClass:"tag-container"},[t("span",{staticClass:"tag-text"},[e._v(e._s(e.$t("users.sandbox")))]),e._v(" "),t("el-button-group",{staticClass:"tag-button-group"},[t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.addTagForMultipleUsers("mrf_tag:sandbox")}}},[e._v("\n            "+e._s(e.$t("users.apply"))+"\n          ")]),e._v(" "),t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.removeTagFromMultipleUsers("mrf_tag:sandbox")}}},[e._v("\n            "+e._s(e.$t("users.remove"))+"\n          ")])],1)],1)]):e._e(),e._v(" "),e.tagPolicyEnabled&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{staticClass:"no-hover"},[t("div",{staticClass:"tag-container"},[t("span",{staticClass:"tag-text"},[e._v(e._s(e.$t("users.disableRemoteSubscriptionForMultiple")))]),e._v(" "),t("el-button-group",{staticClass:"tag-button-group"},[t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.addTagForMultipleUsers("mrf_tag:disable-remote-subscription")}}},[e._v("\n            "+e._s(e.$t("users.apply"))+"\n          ")]),e._v(" "),t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.removeTagFromMultipleUsers("mrf_tag:disable-remote-subscription")}}},[e._v("\n            "+e._s(e.$t("users.remove"))+"\n          ")])],1)],1)]):e._e(),e._v(" "),e.tagPolicyEnabled&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{staticClass:"no-hover"},[t("div",{staticClass:"tag-container"},[t("span",{staticClass:"tag-text"},[e._v(e._s(e.$t("users.disableAnySubscriptionForMultiple")))]),e._v(" "),t("el-button-group",{staticClass:"tag-button-group"},[t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.addTagForMultipleUsers("mrf_tag:disable-any-subscription")}}},[e._v("\n            "+e._s(e.$t("users.apply"))+"\n          ")]),e._v(" "),t("el-button",{attrs:{size:"mini"},nativeOn:{click:function(t){return e.removeTagFromMultipleUsers("mrf_tag:disable-any-subscription")}}},[e._v("\n            "+e._s(e.$t("users.remove"))+"\n          ")])],1)],1)]):e._e(),e._v(" "),!e.tagPolicyEnabled&&e.isPrivileged([],["admin"])&&e.isPrivileged(["users_manage_tags"],[])?t("el-dropdown-item",{attrs:{divided:""},nativeOn:{click:function(t){return e.enableTagPolicy.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("users.enableTagPolicy"))+"\n    ")]):e._e()],1):t("el-dropdown-menu",{attrs:{slot:"dropdown"},slot:"dropdown"},[t("el-dropdown-item",{staticClass:"select-users"},[e._v("\n      "+e._s(e.$t("users.selectUsers"))+"\n    ")])],1)],1):e._e()},[],!1,null,"e9bbc6e0",null);t.a=c.exports},rIUS:function(e,t,s){"use strict";var r=s("yXPU"),n=s.n(r),i=s("o0o1"),a=s.n(i),o=s("mSNy"),u={name:"RebootButton",computed:{needReboot:function(){return this.$store.state.app.needReboot}},methods:{restartApp:function(){var e=this;return n()(a.a.mark(function t(){return a.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.prev=0,t.next=3,e.$store.dispatch("RestartApplication");case 3:t.next=8;break;case 5:return t.prev=5,t.t0=t.catch(0),t.abrupt("return");case 8:e.$message({type:"success",message:o.a.t("settings.restartSuccess")});case 9:case"end":return t.stop()}},t,null,[[0,5]])}))()}}},c=s("KHd+"),l=Object(c.a)(u,function(){var e=this._self._c;return this.needReboot?e("el-tooltip",{attrs:{content:this.$t("settings.restartApp"),placement:"bottom-end"}},[e("el-button",{staticClass:"reboot-button",attrs:{type:"warning"},on:{click:this.restartApp}},[e("span",[e("i",{staticClass:"el-icon-refresh"}),this._v("\n      "+this._s(this.$t("settings.instanceReboot"))+"\n    ")])])],1):this._e()},[],!1,null,null,null);t.a=l.exports},rf4N:function(e,t,s){}}]);
//# sourceMappingURL=chunk-1b9d.822ff94d.js.map