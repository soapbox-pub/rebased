(window.webpackJsonp=window.webpackJsonp||[]).push([["chunk-091e"],{"32w9":function(e,n,t){"use strict";t("emju")},"3k4U":function(e,n,t){"use strict";t("vioL")},aSQl:function(e,n,t){"use strict";t.d(n,"a",function(){return p});var o=t("yXPU"),a=t.n(o),r=t("o0o1"),s=t.n(r),i=t("oAJy"),l=t.n(i),c=t("LvDl"),u=t.n(c),p=function(){var e=a()(s.a.mark(function e(n){var t,o;return s.a.wrap(function(e){for(;;)switch(e.prev=e.next){case 0:return e.next=2,l.a.getItem("vuex-lz");case 2:if(t=e.sent,void 0!==(o=u.a.get(t,"oauth.userToken"))){e.next=6;break}throw new Error("PleromaFE token not found");case 6:return e.next=8,n.dispatch("LoginByPleromaFE",{token:o});case 8:case"end":return e.stop()}},e)}));return function(n){return e.apply(this,arguments)}}()},emju:function(e,n,t){},ntYl:function(e,n,t){"use strict";t.r(n);var o=t("J4zp"),a=t.n(o),r=t("yXPU"),s=t.n(r),i=t("o0o1"),l=t.n(i),c=t("zT9a"),u=t("oAJy"),p=t.n(u),d=t("LvDl"),m=t.n(d),g=t("mSNy"),v=t("aSQl"),h={name:"Login",components:{"svg-icon":c.a},data:function(){return{loginForm:{username:"",password:""},passwordType:"password",loading:!1,loadingPleromaFE:!1,showDialog:!1,redirect:void 0,pleromaFEToken:!1,pleromaFEStateKey:"vuex-lz",pleromaFEState:{}}},watch:{$route:{handler:function(e){this.redirect=e.query&&e.query.redirect},immediate:!0}},mounted:function(){var e=this;return s()(l.a.mark(function n(){var t;return l.a.wrap(function(n){for(;;)switch(n.prev=n.next){case 0:return n.next=2,p.a.getItem(e.pleromaFEStateKey);case 2:if(t=n.sent,e.pleromaFEState=t,void 0!==m.a.get(t,"oauth.userToken")){n.next=6;break}return n.abrupt("return");case 6:e.pleromaFEToken=!0;case 7:case"end":return n.stop()}},n)}))()},methods:{showPwd:function(){"password"===this.passwordType?this.passwordType="":this.passwordType="password"},handleLogin:function(){var e=this;this.loading=!0;var n=this.getLoginData();this.$store.dispatch("LoginByUsername",n).then(function(){e.loading=!1,e.$router.push({path:e.redirect||"/users/index"})}).catch(function(){e.loading=!1})},handlePleromaFELogin:function(){var e=this;return s()(l.a.mark(function n(){return l.a.wrap(function(n){for(;;)switch(n.prev=n.next){case 0:return e.loadingPleromaFE=!0,n.prev=1,n.next=4,Object(v.a)(e.$store);case 4:n.next=10;break;case 6:n.prev=6,n.t0=n.catch(1),e.loadingPleromaFE=!1,e.$message.error(g.a.t("login.pleromaFELoginFailed"));case 10:e.loadingPleromaFE=!1,e.$message.success(g.a.t("login.pleromaFELoginSucceed")),e.$router.push({path:e.redirect||"/users/index"});case 13:case"end":return n.stop()}},n,null,[[1,6]])}))()},getLoginData:function(){var e=this.loginForm.username.split("@"),n=a()(e,2),t=n[0],o=n[1];return{username:t.trim(),authHost:o?o.trim():window.location.host,password:this.loginForm.password}}}},f=(t("32w9"),t("3k4U"),t("KHd+")),w=Object(f.a)(h,function(){var e=this,n=e._self._c;return n("div",{staticClass:"login-container"},[n("el-form",{ref:"loginForm",staticClass:"login-form",attrs:{model:e.loginForm,"auto-complete":"on","label-position":"left"}},[n("div",{staticClass:"title-container"},[n("h3",{staticClass:"title"},[e._v("\n        "+e._s(e.$t("login.title"))+"\n      ")])]),e._v(" "),n("el-form-item",{attrs:{prop:"username"}},[n("span",{staticClass:"svg-container"},[n("i",{staticClass:"el-icon-user"})]),e._v(" "),n("el-input",{attrs:{placeholder:e.$t("login.username"),name:"username",type:"text","auto-complete":"on"},model:{value:e.loginForm.username,callback:function(n){e.$set(e.loginForm,"username",n)},expression:"loginForm.username"}})],1),e._v(" "),n("div",{staticClass:"omit-host-note"},[e._v(e._s(e.$t("login.omitHostname")))]),e._v(" "),n("el-form-item",{attrs:{prop:"password"}},[n("span",{staticClass:"svg-container"},[n("i",{staticClass:"el-icon-key"})]),e._v(" "),n("el-input",{attrs:{type:e.passwordType,placeholder:e.$t("login.password"),name:"password","auto-complete":"on"},nativeOn:{keyup:function(n){return!n.type.indexOf("key")&&e._k(n.keyCode,"enter",13,n.key,"Enter")?null:e.handleLogin.apply(null,arguments)}},model:{value:e.loginForm.password,callback:function(n){e.$set(e.loginForm,"password",n)},expression:"loginForm.password"}}),e._v(" "),n("span",{staticClass:"show-pwd",on:{click:e.showPwd}},[n("svg-icon",{attrs:{"icon-class":"password"===e.passwordType?"eye":"eye-open"}})],1)],1),e._v(" "),n("el-button",{staticClass:"login-button",attrs:{loading:e.loading,type:"primary"},nativeOn:{click:function(n){return n.preventDefault(),e.handleLogin.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("login.logIn"))+"\n    ")]),e._v(" "),e.pleromaFEToken?n("el-button",{staticClass:"login-button",attrs:{loading:e.loadingPleromaFE,type:"primary"},nativeOn:{click:function(n){return n.preventDefault(),e.handlePleromaFELogin.apply(null,arguments)}}},[e._v("\n      "+e._s(e.$t("login.logInViaPleromaFE"))+"\n    ")]):e._e()],1)],1)},[],!1,null,"0503310e",null);n.default=w.exports},vioL:function(e,n,t){}}]);
//# sourceMappingURL=chunk-091e.555ed3c2.js.map