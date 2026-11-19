import "./lib/uiScale";
import { mount } from "svelte";
import App from "./App.svelte";
import "./index.css";
import "./scrollBar.css";
import "./styles/element.css";

mount(App, { target: document.getElementById("app")! });
