import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Home } from "./pages/Home";
import { NotFound } from "./pages/NotFound";
import ActiveSectionContextProvider from "./context/active-section-context";

function App() {
  return (
    <ActiveSectionContextProvider>
      <BrowserRouter>
        <Routes>
          <Route index element={<Home />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </ActiveSectionContextProvider>
  );
}

export default App;

