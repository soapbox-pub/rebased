(window.webpackJsonp=window.webpackJsonp||[]).push([[241],{831:function(e,t,a){"use strict";a.r(t),a.d(t,"default",(function(){return g}));var o,i,s,r=a(0),n=a(2),l=(a(9),a(6),a(8)),c=a(1),d=a(3),m=a.n(d),b=a(5),u=a.n(b),p=a(21),f=a(7),h=a(12),j=a(53);var O=Object(f.f)({close:{id:"lightbox.close",defaultMessage:"Close"}}),g=Object(f.g)((s=i=function(e){Object(l.a)(a,e);var t;t=a;function a(){for(var t,a=arguments.length,o=new Array(a),i=0;i<a;i++)o[i]=arguments[i];return t=e.call.apply(e,[this].concat(o))||this,Object(c.a)(Object(n.a)(t),"state",{loading:!1,oembed:null}),Object(c.a)(Object(n.a)(t),"setIframeRef",(function(e){t.iframe=e})),Object(c.a)(Object(n.a)(t),"handleTextareaClick",(function(e){e.target.select()})),t}var o=a.prototype;return o.componentDidMount=function(){var e=this,t=this.props.url;this.setState({loading:!0}),Object(h.a)().post("/api/web/embed",{url:t}).then((function(t){e.setState({loading:!1,oembed:t.data});var a=e.iframe.contentWindow.document;a.open(),a.write(t.data.html),a.close(),a.body.style.margin=0,e.iframe.width=a.body.scrollWidth,e.iframe.height=a.body.scrollHeight})).catch((function(t){e.props.onError(t)}))},o.render=function(){var e=this.props,t=e.intl,a=e.onClose,o=this.state.oembed;return Object(r.a)("div",{className:"modal-root__modal report-modal embed-modal"},void 0,Object(r.a)("div",{className:"report-modal__target"},void 0,Object(r.a)(j.a,{className:"media-modal__close",title:t.formatMessage(O.close),icon:"times",onClick:a,size:16}),Object(r.a)(f.b,{id:"status.embed",defaultMessage:"Embed"})),Object(r.a)("div",{className:"report-modal__container embed-modal__container",style:{display:"block"}},void 0,Object(r.a)("p",{className:"hint"},void 0,Object(r.a)(f.b,{id:"embed.instructions",defaultMessage:"Embed this status on your website by copying the code below."})),Object(r.a)("input",{type:"text",className:"embed-modal__html",readOnly:!0,value:o&&o.html||"",onClick:this.handleTextareaClick}),Object(r.a)("p",{className:"hint"},void 0,Object(r.a)(f.b,{id:"embed.preview",defaultMessage:"Here is what it will look like:"})),m.a.createElement("iframe",{className:"embed-modal__iframe",frameBorder:"0",ref:this.setIframeRef,sandbox:"allow-same-origin",title:"preview"})))},a}(p.a),Object(c.a)(i,"propTypes",{url:u.a.string.isRequired,onClose:u.a.func.isRequired,onError:u.a.func.isRequired,intl:u.a.object.isRequired}),o=s))||o}}]);
//# sourceMappingURL=embed_modal.js.map