(window.webpackJsonp=window.webpackJsonp||[]).push([["chunk-e458"],{FtQ1:function(t,s,e){"use strict";e.r(s);var a=e("RIqP"),n=e.n(a),i=e("i7Kn"),o=e("ot3S"),r=e("rIUS"),c=e("ZhIB"),u=e.n(c),l={name:"Statuses",components:{MultipleUsersMenu:i.a,RebootButton:r.a,Status:o.a},data:function(){return{selectedUsers:[]}},computed:{allLoaded:function(){return this.$store.state.status.statusesByInstance.allLoaded},buttonLoading:function(){return this.$store.state.status.statusesByInstance.buttonLoading},currentInstance:function(){return this.selectedInstance===this.$store.state.user.authHost},instances:function(){return[this.$store.state.user.authHost].concat(n()(this.$store.state.peers.fetchedPeers))},isDesktop:function(){return"desktop"===this.$store.state.app.device},isMobile:function(){return"mobile"===this.$store.state.app.device},isTablet:function(){return"tablet"===this.$store.state.app.device},loadingPeers:function(){return this.$store.state.peers.loading},page:function(){return this.$store.state.status.statusesByInstance.page},pageSize:function(){return this.$store.state.status.statusesByInstance.pageSize},selectedInstance:{get:function(){return this.$store.state.status.statusesByInstance.selectedInstance},set:function(t){this.$store.dispatch("HandleFilterChange",t)}},showLocal:{get:function(){return this.$store.state.status.statusesByInstance.showLocal},set:function(t){this.$store.dispatch("HandleLocalCheckboxChange",t)}},showPrivate:{get:function(){return this.$store.state.status.statusesByInstance.showPrivate},set:function(t){this.$store.dispatch("HandleGodmodeCheckboxChange",t)}},statuses:function(){return this.$store.state.status.fetchedStatuses},statusVisibility:function(){return this.$store.state.status.statusVisibility}},mounted:function(){this.$store.dispatch("GetNodeInfo"),this.$store.dispatch("NeedReboot"),this.$store.dispatch("FetchPeers"),this.$store.dispatch("FetchStatusesCount")},destroyed:function(){this.clearSelection(),this.$store.dispatch("ClearState")},methods:{clearSelection:function(){this.selectedUsers=[]},handleFilterChange:function(){this.$store.dispatch("HandlePageChange",1),this.$store.dispatch("FetchStatusesByInstance")},handleLoadMore:function(){this.$store.dispatch("HandlePageChange",this.page+1),this.$store.dispatch("FetchStatusesPageByInstance")},handleStatusSelection:function(t){void 0===this.selectedUsers.find(function(s){return t.id===s.id})&&(this.selectedUsers=[].concat(n()(this.selectedUsers),[t]))},normalizedCount:function(t){return u()(t).format("0a")}}},d=(e("QOJ7"),e("KHd+")),h=Object(d.a)(l,function(){var t=this,s=t.$createElement,e=t._self._c||s;return t.loadingPeers?t._e():e("div",{staticClass:"statuses-container"},[e("div",{staticClass:"statuses-header"},[e("h1",[t._v("\n      "+t._s(t.$t("statuses.statuses"))+"\n    ")]),t._v(" "),e("reboot-button")],1),t._v(" "),e("div",{staticClass:"statuses-header-container"},[e("el-button-group",[e("el-button",{staticClass:"direct-button",attrs:{plain:""}},[t._v("\n        "+t._s(t.$t("statuses.direct"))+": "+t._s(t.normalizedCount(t.statusVisibility.direct))+"\n      ")]),t._v(" "),e("el-button",{staticClass:"private-button",attrs:{plain:""}},[t._v("\n        "+t._s(t.$t("statuses.private"))+": "+t._s(t.normalizedCount(t.statusVisibility.private))+"\n      ")]),t._v(" "),e("el-button",{staticClass:"public-button",attrs:{plain:""}},[t._v("\n        "+t._s(t.$t("statuses.public"))+": "+t._s(t.normalizedCount(t.statusVisibility.public))+"\n      ")]),t._v(" "),e("el-button",{staticClass:"unlisted-button",attrs:{plain:""}},[t._v("\n        "+t._s(t.$t("statuses.unlisted"))+": "+t._s(t.normalizedCount(t.statusVisibility.unlisted))+"\n      ")])],1)],1),t._v(" "),e("div",{staticClass:"filter-container"},[e("el-select",{staticClass:"select-instance",attrs:{placeholder:t.$t("statuses.instanceFilter"),"no-data-text":t.$t("statuses.noInstances"),filterable:"",clearable:""},on:{change:t.handleFilterChange},model:{value:t.selectedInstance,callback:function(s){t.selectedInstance=s},expression:"selectedInstance"}},t._l(t.instances,function(t,s){return e("el-option",{key:s,attrs:{label:t,value:t}})}),1),t._v(" "),e("multiple-users-menu",{attrs:{"selected-users":t.selectedUsers},on:{"apply-action":t.clearSelection}})],1),t._v(" "),t.currentInstance?e("div",{staticClass:"checkbox-container"},[e("el-checkbox",{staticClass:"show-private-statuses",model:{value:t.showLocal,callback:function(s){t.showLocal=s},expression:"showLocal"}},[t._v("\n      "+t._s(t.$t("statuses.onlyLocalStatuses"))+"\n    ")]),t._v(" "),e("el-checkbox",{staticClass:"show-private-statuses",model:{value:t.showPrivate,callback:function(s){t.showPrivate=s},expression:"showPrivate"}},[t._v("\n      "+t._s(t.$t("statuses.showPrivateStatuses"))+"\n    ")])],1):t._e(),t._v(" "),0===t.statuses.length?e("p",{staticClass:"no-statuses"},[t._v(t._s(t.$t("userProfile.noStatuses")))]):t._e(),t._v(" "),t._l(t.statuses,function(s){return e("div",{key:s.id,staticClass:"status-container"},[e("status",{attrs:{status:s,account:s.account,"show-checkbox":t.isDesktop,"fetch-statuses-by-instance":!0},on:{"status-selection":t.handleStatusSelection}})],1)}),t._v(" "),t.statuses.length>0?e("div",{staticClass:"statuses-pagination"},[t.allLoaded?e("el-button",{attrs:{icon:"el-icon-check",circle:""}}):e("el-button",{attrs:{loading:t.buttonLoading},on:{click:t.handleLoadMore}},[t._v(t._s(t.$t("statuses.loadMore")))])],1):t._e()],2)},[],!1,null,null,null);h.options.__file="index.vue";s.default=h.exports},KmHg:function(t,s,e){},Kw8l:function(t,s,e){"use strict";var a=e("cRgN");e.n(a).a},QOJ7:function(t,s,e){"use strict";var a=e("KmHg");e.n(a).a},RnhZ:function(t,s,e){var a={"./af":"K/tc","./af.js":"K/tc","./ar":"jnO4","./ar-dz":"o1bE","./ar-dz.js":"o1bE","./ar-kw":"Qj4J","./ar-kw.js":"Qj4J","./ar-ly":"HP3h","./ar-ly.js":"HP3h","./ar-ma":"CoRJ","./ar-ma.js":"CoRJ","./ar-sa":"gjCT","./ar-sa.js":"gjCT","./ar-tn":"bYM6","./ar-tn.js":"bYM6","./ar.js":"jnO4","./az":"SFxW","./az.js":"SFxW","./be":"H8ED","./be.js":"H8ED","./bg":"hKrs","./bg.js":"hKrs","./bm":"p/rL","./bm.js":"p/rL","./bn":"kEOa","./bn.js":"kEOa","./bo":"0mo+","./bo.js":"0mo+","./br":"aIdf","./br.js":"aIdf","./bs":"JVSJ","./bs.js":"JVSJ","./ca":"1xZ4","./ca.js":"1xZ4","./cs":"PA2r","./cs.js":"PA2r","./cv":"A+xa","./cv.js":"A+xa","./cy":"l5ep","./cy.js":"l5ep","./da":"DxQv","./da.js":"DxQv","./de":"tGlX","./de-at":"s+uk","./de-at.js":"s+uk","./de-ch":"u3GI","./de-ch.js":"u3GI","./de.js":"tGlX","./dv":"WYrj","./dv.js":"WYrj","./el":"jUeY","./el.js":"jUeY","./en-SG":"zavE","./en-SG.js":"zavE","./en-au":"Dmvi","./en-au.js":"Dmvi","./en-ca":"OIYi","./en-ca.js":"OIYi","./en-gb":"Oaa7","./en-gb.js":"Oaa7","./en-ie":"4dOw","./en-ie.js":"4dOw","./en-il":"czMo","./en-il.js":"czMo","./en-nz":"b1Dy","./en-nz.js":"b1Dy","./eo":"Zduo","./eo.js":"Zduo","./es":"iYuL","./es-do":"CjzT","./es-do.js":"CjzT","./es-us":"Vclq","./es-us.js":"Vclq","./es.js":"iYuL","./et":"7BjC","./et.js":"7BjC","./eu":"D/JM","./eu.js":"D/JM","./fa":"jfSC","./fa.js":"jfSC","./fi":"gekB","./fi.js":"gekB","./fo":"ByF4","./fo.js":"ByF4","./fr":"nyYc","./fr-ca":"2fjn","./fr-ca.js":"2fjn","./fr-ch":"Dkky","./fr-ch.js":"Dkky","./fr.js":"nyYc","./fy":"cRix","./fy.js":"cRix","./ga":"USCx","./ga.js":"USCx","./gd":"9rRi","./gd.js":"9rRi","./gl":"iEDd","./gl.js":"iEDd","./gom-latn":"DKr+","./gom-latn.js":"DKr+","./gu":"4MV3","./gu.js":"4MV3","./he":"x6pH","./he.js":"x6pH","./hi":"3E1r","./hi.js":"3E1r","./hr":"S6ln","./hr.js":"S6ln","./hu":"WxRl","./hu.js":"WxRl","./hy-am":"1rYy","./hy-am.js":"1rYy","./id":"UDhR","./id.js":"UDhR","./is":"BVg3","./is.js":"BVg3","./it":"bpih","./it-ch":"bxKX","./it-ch.js":"bxKX","./it.js":"bpih","./ja":"B55N","./ja.js":"B55N","./jv":"tUCv","./jv.js":"tUCv","./ka":"IBtZ","./ka.js":"IBtZ","./kk":"bXm7","./kk.js":"bXm7","./km":"6B0Y","./km.js":"6B0Y","./kn":"PpIw","./kn.js":"PpIw","./ko":"Ivi+","./ko.js":"Ivi+","./ku":"JCF/","./ku.js":"JCF/","./ky":"lgnt","./ky.js":"lgnt","./lb":"RAwQ","./lb.js":"RAwQ","./lo":"sp3z","./lo.js":"sp3z","./lt":"JvlW","./lt.js":"JvlW","./lv":"uXwI","./lv.js":"uXwI","./me":"KTz0","./me.js":"KTz0","./mi":"aIsn","./mi.js":"aIsn","./mk":"aQkU","./mk.js":"aQkU","./ml":"AvvY","./ml.js":"AvvY","./mn":"lYtQ","./mn.js":"lYtQ","./mr":"Ob0Z","./mr.js":"Ob0Z","./ms":"6+QB","./ms-my":"ZAMP","./ms-my.js":"ZAMP","./ms.js":"6+QB","./mt":"G0Uy","./mt.js":"G0Uy","./my":"honF","./my.js":"honF","./nb":"bOMt","./nb.js":"bOMt","./ne":"OjkT","./ne.js":"OjkT","./nl":"+s0g","./nl-be":"2ykv","./nl-be.js":"2ykv","./nl.js":"+s0g","./nn":"uEye","./nn.js":"uEye","./pa-in":"8/+R","./pa-in.js":"8/+R","./pl":"jVdC","./pl.js":"jVdC","./pt":"8mBD","./pt-br":"0tRk","./pt-br.js":"0tRk","./pt.js":"8mBD","./ro":"lyxo","./ro.js":"lyxo","./ru":"lXzo","./ru.js":"lXzo","./sd":"Z4QM","./sd.js":"Z4QM","./se":"//9w","./se.js":"//9w","./si":"7aV9","./si.js":"7aV9","./sk":"e+ae","./sk.js":"e+ae","./sl":"gVVK","./sl.js":"gVVK","./sq":"yPMs","./sq.js":"yPMs","./sr":"zx6S","./sr-cyrl":"E+lV","./sr-cyrl.js":"E+lV","./sr.js":"zx6S","./ss":"Ur1D","./ss.js":"Ur1D","./sv":"X709","./sv.js":"X709","./sw":"dNwA","./sw.js":"dNwA","./ta":"PeUW","./ta.js":"PeUW","./te":"XLvN","./te.js":"XLvN","./tet":"V2x9","./tet.js":"V2x9","./tg":"Oxv6","./tg.js":"Oxv6","./th":"EOgW","./th.js":"EOgW","./tl-ph":"Dzi0","./tl-ph.js":"Dzi0","./tlh":"z3Vd","./tlh.js":"z3Vd","./tr":"DoHr","./tr.js":"DoHr","./tzl":"z1FC","./tzl.js":"z1FC","./tzm":"wQk9","./tzm-latn":"tT3J","./tzm-latn.js":"tT3J","./tzm.js":"wQk9","./ug-cn":"YRex","./ug-cn.js":"YRex","./uk":"raLr","./uk.js":"raLr","./ur":"UpQW","./ur.js":"UpQW","./uz":"Loxo","./uz-latn":"AQ68","./uz-latn.js":"AQ68","./uz.js":"Loxo","./vi":"KSF8","./vi.js":"KSF8","./x-pseudo":"/X5v","./x-pseudo.js":"/X5v","./yo":"fzPg","./yo.js":"fzPg","./zh-cn":"XDpg","./zh-cn.js":"XDpg","./zh-hk":"SatO","./zh-hk.js":"SatO","./zh-tw":"kOpN","./zh-tw.js":"kOpN"};function n(t){var s=i(t);return e(s)}function i(t){if(!e.o(a,t)){var s=new Error("Cannot find module '"+t+"'");throw s.code="MODULE_NOT_FOUND",s}return a[t]}n.keys=function(){return Object.keys(a)},n.resolve=i,t.exports=n,n.id="RnhZ"},cRgN:function(t,s,e){},ot3S:function(t,s,e){"use strict";var a=e("wd/R"),n=e.n(a),i={name:"Status",props:{account:{type:Object,required:!1,default:function(){return{}}},fetchStatusesByInstance:{type:Boolean,required:!1,default:!1},showCheckbox:{type:Boolean,required:!0,default:!1},status:{type:Object,required:!0},page:{type:Number,required:!1,default:0},userId:{type:String,required:!1,default:""},godmode:{type:Boolean,required:!1,default:!1}},data:function(){return{showHiddenStatus:!1}},methods:{capitalizeFirstLetter:function(t){return t.charAt(0).toUpperCase()+t.slice(1)},changeStatus:function(t,s,e){this.$store.dispatch("ChangeStatusScope",{statusId:t,isSensitive:s,visibility:e,reportCurrentPage:this.page,userId:this.userId,godmode:this.godmode,fetchStatusesByInstance:this.fetchStatusesByInstance})},deleteStatus:function(t){var s=this;this.$confirm("Are you sure you want to delete this status?","Warning",{confirmButtonText:"OK",cancelButtonText:"Cancel",type:"warning"}).then(function(){s.$store.dispatch("DeleteStatus",{statusId:t,reportCurrentPage:s.page,userId:s.userId,godmode:s.godmode,fetchStatusesByInstance:s.fetchStatusesByInstance}),s.$message({type:"success",message:"Delete completed"})}).catch(function(){s.$message({type:"info",message:"Delete canceled"})})},optionPercent:function(t,s){var e=t.options.reduce(function(t,s){return t+s.votes_count},0);return 0===e?0:+(s.votes_count/e*100).toFixed(1)},parseTimestamp:function(t){return n()(t).format("YYYY-MM-DD HH:mm")},handleStatusSelection:function(t){this.$emit("status-selection",t)}}},o=(e("Kw8l"),e("KHd+")),r=Object(o.a)(i,function(){var t=this,s=t.$createElement,e=t._self._c||s;return e("div",[t.status.deleted?e("el-card",{staticClass:"status-card"},[e("div",{attrs:{slot:"header"},slot:"header"},[e("div",{staticClass:"status-header"},[e("div",{staticClass:"status-account-container"},[e("div",{staticClass:"status-account"},[e("h4",{staticClass:"status-deleted"},[t._v(t._s(t.$t("reports.statusDeleted")))])])])])]),t._v(" "),e("div",{staticClass:"status-body"},[t.status.content?e("span",{staticClass:"status-content",domProps:{innerHTML:t._s(t.status.content)}}):e("span",{staticClass:"status-without-content"},[t._v("no content")])]),t._v(" "),t.status.created_at?e("a",{staticClass:"account",attrs:{href:t.status.url,target:"_blank"}},[t._v("\n      "+t._s(t.parseTimestamp(t.status.created_at))+"\n    ")]):t._e()]):e("el-card",{staticClass:"status-card"},[e("div",{attrs:{slot:"header"},slot:"header"},[e("div",{staticClass:"status-header"},[e("div",{staticClass:"status-account-container"},[e("div",{staticClass:"status-account"},[t.showCheckbox?e("el-checkbox",{staticClass:"status-checkbox",on:{change:function(s){return t.handleStatusSelection(t.account)}}}):t._e(),t._v(" "),e("img",{staticClass:"status-avatar-img",attrs:{src:t.account.avatar}}),t._v(" "),t.account.deactivated?e("span",[e("h3",{staticClass:"status-account-name"},[t._v(t._s(t.account.display_name))]),t._v(" "),e("h3",{staticClass:"status-account-name deactivated"},[t._v(" (deactivated)")])]):e("a",{staticClass:"account",attrs:{href:t.account.url,target:"_blank"}},[e("h3",{staticClass:"status-account-name"},[t._v(t._s(t.account.display_name))])])],1)]),t._v(" "),e("div",{staticClass:"status-actions"},[t.status.sensitive?e("el-tag",{attrs:{type:"warning",size:"large"}},[t._v(t._s(t.$t("reports.sensitive")))]):t._e(),t._v(" "),e("el-tag",{attrs:{size:"large"}},[t._v(t._s(t.capitalizeFirstLetter(t.status.visibility)))]),t._v(" "),e("el-dropdown",{attrs:{trigger:"click"}},[e("el-button",{staticClass:"status-actions-button",attrs:{plain:"",size:"small",icon:"el-icon-edit"}},[t._v("\n              "+t._s(t.$t("reports.changeScope"))),e("i",{staticClass:"el-icon-arrow-down el-icon--right"})]),t._v(" "),e("el-dropdown-menu",{attrs:{slot:"dropdown"},slot:"dropdown"},[t.status.sensitive?t._e():e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,!0,t.status.visibility)}}},[t._v("\n                "+t._s(t.$t("reports.addSensitive"))+"\n              ")]),t._v(" "),t.status.sensitive?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,!1,t.status.visibility)}}},[t._v("\n                "+t._s(t.$t("reports.removeSensitive"))+"\n              ")]):t._e(),t._v(" "),"public"!==t.status.visibility?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,t.status.sensitive,"public")}}},[t._v("\n                "+t._s(t.$t("reports.public"))+"\n              ")]):t._e(),t._v(" "),"private"!==t.status.visibility?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,t.status.sensitive,"private")}}},[t._v("\n                "+t._s(t.$t("reports.private"))+"\n              ")]):t._e(),t._v(" "),"unlisted"!==t.status.visibility?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,t.status.sensitive,"unlisted")}}},[t._v("\n                "+t._s(t.$t("reports.unlisted"))+"\n              ")]):t._e(),t._v(" "),e("el-dropdown-item",{nativeOn:{click:function(s){return t.deleteStatus(t.status.id)}}},[t._v("\n                "+t._s(t.$t("reports.deleteStatus"))+"\n              ")])],1)],1)],1)])]),t._v(" "),e("div",{staticClass:"status-body"},[t.status.spoiler_text?e("div",[e("strong",[t._v(t._s(t.status.spoiler_text))]),t._v(" "),t.showHiddenStatus?t._e():e("el-button",{staticClass:"show-more-button",attrs:{size:"mini"},on:{click:function(s){t.showHiddenStatus=!0}}},[t._v("Show more")]),t._v(" "),t.showHiddenStatus?e("el-button",{staticClass:"show-more-button",attrs:{size:"mini"},on:{click:function(s){t.showHiddenStatus=!1}}},[t._v("Show less")]):t._e(),t._v(" "),t.showHiddenStatus?e("div",[e("span",{staticClass:"status-content",domProps:{innerHTML:t._s(t.status.content)}}),t._v(" "),t.status.poll?e("div",{staticClass:"poll"},[e("ul",t._l(t.status.poll.options,function(s,a){return e("li",{key:a},[t._v("\n                "+t._s(s.title)+"\n                "),e("el-progress",{attrs:{percentage:t.optionPercent(t.status.poll,s)}})],1)}),0)]):t._e(),t._v(" "),t._l(t.status.media_attachments,function(t,s){return e("div",{key:s,staticClass:"image"},[e("img",{attrs:{src:t.preview_url}})])})],2):t._e()],1):t._e(),t._v(" "),t.status.spoiler_text?t._e():e("div",[e("span",{staticClass:"status-content",domProps:{innerHTML:t._s(t.status.content)}}),t._v(" "),t.status.poll?e("div",{staticClass:"poll"},[e("ul",t._l(t.status.poll.options,function(s,a){return e("li",{key:a},[t._v("\n              "+t._s(s.title)+"\n              "),e("el-progress",{attrs:{percentage:t.optionPercent(t.status.poll,s)}})],1)}),0)]):t._e(),t._v(" "),t._l(t.status.media_attachments,function(t,s){return e("div",{key:s,staticClass:"image"},[e("img",{attrs:{src:t.preview_url}})])})],2),t._v(" "),e("a",{staticClass:"account",attrs:{href:t.status.url,target:"_blank"}},[t._v("\n        "+t._s(t.parseTimestamp(t.status.created_at))+"\n      ")])])])],1)},[],!1,null,null,null);r.options.__file="index.vue";s.a=r.exports}}]);
//# sourceMappingURL=chunk-e458.bb460d81.js.map