(window.webpackJsonp=window.webpackJsonp||[]).push([["chunk-9bb9"],{"9/5/":function(e,t,n){(function(t){var n="Expected a function",a=NaN,r="[object Symbol]",i=/^\s+|\s+$/g,s=/^[-+]0x[0-9a-f]+$/i,o=/^0b[01]+$/i,c=/^0o[0-7]+$/i,l=parseInt,u="object"==typeof t&&t&&t.Object===Object&&t,d="object"==typeof self&&self&&self.Object===Object&&self,h=u||d||Function("return this")(),p=Object.prototype.toString,f=Math.max,m=Math.min,v=function(){return h.Date.now()};function b(e){var t=typeof e;return!!e&&("object"==t||"function"==t)}function y(e){if("number"==typeof e)return e;if(function(e){return"symbol"==typeof e||function(e){return!!e&&"object"==typeof e}(e)&&p.call(e)==r}(e))return a;if(b(e)){var t="function"==typeof e.valueOf?e.valueOf():e;e=b(t)?t+"":t}if("string"!=typeof e)return 0===e?e:+e;e=e.replace(i,"");var n=o.test(e);return n||c.test(e)?l(e.slice(2),n?2:8):s.test(e)?a:+e}e.exports=function(e,t,a){var r,i,s,o,c,l,u=0,d=!1,h=!1,p=!0;if("function"!=typeof e)throw new TypeError(n);function x(t){var n=r,a=i;return r=i=void 0,u=t,o=e.apply(a,n)}function g(e){var n=e-l;return void 0===l||n>=t||n<0||h&&e-u>=s}function C(){var e=v();if(g(e))return $(e);c=setTimeout(C,function(e){var n=t-(e-l);return h?m(n,s-(e-u)):n}(e))}function $(e){return c=void 0,p&&r?x(e):(r=i=void 0,o)}function _(){var e=v(),n=g(e);if(r=arguments,i=this,l=e,n){if(void 0===c)return function(e){return u=e,c=setTimeout(C,t),d?x(e):o}(l);if(h)return c=setTimeout(C,t),x(l)}return void 0===c&&(c=setTimeout(C,t)),o}return t=y(t)||0,b(a)&&(d=!!a.leading,s=(h="maxWait"in a)?f(y(a.maxWait)||0,t):s,p="trailing"in a?!!a.trailing:p),_.cancel=function(){void 0!==c&&clearTimeout(c),u=0,r=l=i=c=void 0},_.flush=function(){return void 0===c?o:$(v())},_}}).call(this,n("yLpj"))},RmIN:function(e,t,n){"use strict";n("qX4l")},mAEd:function(e,t,n){"use strict";n.r(t);var a=n("9/5/"),r=n.n(a),i={name:"MediaProxyCache",components:{RebootButton:n("rIUS").a},data:function(){return{urls:"",ban:!1,search:"",selectedUrls:[]}},computed:{bannedUrls:function(){return this.$store.state.mediaProxyCache.bannedUrls},currentPage:function(){return this.$store.state.mediaProxyCache.currentPage},isDesktop:function(){return"desktop"===this.$store.state.app.device},loading:function(){return this.$store.state.mediaProxyCache.loading},mediaProxyEnabled:function(){return this.$store.state.mediaProxyCache.mediaProxyEnabled},pageSize:function(){return this.$store.state.mediaProxyCache.pageSize},removeSelectedDisabled:function(){return 0===this.selectedUrls.length},urlsCount:function(){return this.$store.state.mediaProxyCache.totalUrlsCount}},created:function(){var e=this;this.handleDebounceSearchInput=r()(function(t){e.$store.dispatch("SearchUrls",{query:t,page:1})},500)},mounted:function(){this.$store.dispatch("GetNodeInfo"),this.$store.dispatch("NeedReboot"),this.$store.dispatch("FetchMediaProxySetting"),this.$store.dispatch("ListBannedUrls",{page:1})},methods:{enableMediaProxy:function(){var e=this;this.$confirm(this.$t("mediaProxyCache.confirmEnablingMediaProxy"),{confirmButtonText:"Yes",cancelButtonText:"Cancel",type:"warning"}).then(function(){e.$message({type:"success",message:e.$t("mediaProxyCache.enableMediaProxySuccessMessage")}),e.$store.dispatch("EnableMediaProxy")}).catch(function(){e.$message({type:"info",message:"Canceled"})})},evictURL:function(){var e=this.splitUrls(this.urls);this.$store.dispatch("PurgeUrls",{urls:e,ban:this.ban}),this.urls=""},handlePageChange:function(e){this.$store.dispatch("ListBannedUrls",{page:e})},handleSelectionChange:function(e){this.$data.selectedUrls=e},removeSelected:function(){var e=this.selectedUrls.map(function(e){return e.url});this.$store.dispatch("RemoveBannedUrls",e),this.selectedUrls=[]},removeUrl:function(e){this.$store.dispatch("RemoveBannedUrls",[e])},splitUrls:function(e){return e.split(",").map(function(e){return e.trim()}).filter(function(e){return e.length>0})}}},s=(n("RmIN"),n("KHd+")),o=Object(s.a)(i,function(){var e=this,t=e._self._c;return t("div",{staticClass:"media-proxy-cache-container"},[t("div",{staticClass:"media-proxy-cache-header-container"},[t("h1",[e._v(e._s(e.$t("mediaProxyCache.mediaProxyCache")))]),e._v(" "),t("reboot-button")],1),e._v(" "),e.mediaProxyEnabled?t("div",[t("p",{staticClass:"media-proxy-cache-header"},[e._v(e._s(e.$t("mediaProxyCache.evictObjectsHeader")))]),e._v(" "),t("div",{staticClass:"url-input-container"},[t("el-input",{staticClass:"url-input",attrs:{placeholder:e.$t("mediaProxyCache.url"),type:"textarea",autosize:"",clearable:""},model:{value:e.urls,callback:function(t){e.urls=t},expression:"urls"}}),e._v(" "),t("el-checkbox",{model:{value:e.ban,callback:function(t){e.ban=t},expression:"ban"}},[e._v(e._s(e.$t("mediaProxyCache.ban")))]),e._v(" "),t("el-button",{staticClass:"evict-button",on:{click:e.evictURL}},[e._v(e._s(e.$t("mediaProxyCache.evict")))])],1),e._v(" "),t("span",{staticClass:"expl url-input-expl"},[e._v(e._s(e.$t("mediaProxyCache.multipleInput")))]),e._v(" "),t("p",{staticClass:"media-proxy-cache-header"},[e._v(e._s(e.$t("mediaProxyCache.listBannedUrlsHeader")))]),e._v(" "),t("el-table",{directives:[{name:"loading",rawName:"v-loading",value:e.loading,expression:"loading"}],staticClass:"banned-urls-table",attrs:{data:e.bannedUrls},on:{"selection-change":e.handleSelectionChange}},[e._v(">\n      "),t("el-table-column",{attrs:{type:"selection",align:"center",width:"55"}}),e._v(" "),t("el-table-column",{attrs:{"min-width":e.isDesktop?320:120,prop:"url"},scopedSlots:e._u([{key:"header",fn:function(n){return[t("el-input",{attrs:{placeholder:e.$t("users.search"),size:"mini","prefix-icon":"el-icon-search"},on:{input:e.handleDebounceSearchInput},model:{value:e.search,callback:function(t){e.search=t},expression:"search"}})]}}],null,!1,2430623903)}),e._v(" "),t("el-table-column",{scopedSlots:e._u([{key:"default",fn:function(n){return[t("el-button",{staticClass:"remove-url-button",attrs:{size:"mini"},on:{click:function(t){return e.removeUrl(n.row.url)}}},[e._v(e._s(e.$t("mediaProxyCache.remove")))])]}}],null,!1,3837797105)},[t("template",{slot:"header"},[t("el-button",{staticClass:"remove-url-button",attrs:{disabled:e.removeSelectedDisabled,size:"mini"},on:{click:function(t){return e.removeSelected()}}},[e._v(e._s(e.$t("mediaProxyCache.removeSelected")))])],1)],2)],1),e._v(" "),e.loading?e._e():t("div",{staticClass:"pagination"},[t("el-pagination",{attrs:{total:e.urlsCount,"current-page":e.currentPage,"page-size":e.pageSize,"hide-on-single-page":"",layout:"prev, pager, next"},on:{"current-change":e.handlePageChange}})],1)],1):t("div",{staticClass:"enable-mediaproxy-container"},[t("el-button",{attrs:{type:"text"},on:{click:e.enableMediaProxy}},[e._v(e._s(e.$t("mediaProxyCache.enable")))]),e._v("\n    "+e._s(e.$t("mediaProxyCache.invalidationAndMediaProxy"))+"\n  ")],1)])},[],!1,null,"67d8efe6",null);t.default=o.exports},qX4l:function(e,t,n){},rIUS:function(e,t,n){"use strict";var a=n("yXPU"),r=n.n(a),i=n("o0o1"),s=n.n(i),o=n("mSNy"),c={name:"RebootButton",computed:{needReboot:function(){return this.$store.state.app.needReboot}},methods:{restartApp:function(){var e=this;return r()(s.a.mark(function t(){return s.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.prev=0,t.next=3,e.$store.dispatch("RestartApplication");case 3:t.next=8;break;case 5:return t.prev=5,t.t0=t.catch(0),t.abrupt("return");case 8:e.$message({type:"success",message:o.a.t("settings.restartSuccess")});case 9:case"end":return t.stop()}},t,null,[[0,5]])}))()}}},l=n("KHd+"),u=Object(l.a)(c,function(){var e=this._self._c;return this.needReboot?e("el-tooltip",{attrs:{content:this.$t("settings.restartApp"),placement:"bottom-end"}},[e("el-button",{staticClass:"reboot-button",attrs:{type:"warning"},on:{click:this.restartApp}},[e("span",[e("i",{staticClass:"el-icon-refresh"}),this._v("\n      "+this._s(this.$t("settings.instanceReboot"))+"\n    ")])])],1):this._e()},[],!1,null,null,null);t.a=u.exports}}]);
//# sourceMappingURL=chunk-9bb9.a09acfdd.js.map