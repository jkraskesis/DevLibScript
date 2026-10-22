#include <wx/wx.h>

class SmokeApp : public wxApp
{
public:
    bool OnInit() override
    {
        auto* frame = new wxFrame(nullptr, wxID_ANY, "wxWidgets cross-build");
        frame->Show();
        return true;
    }
};

wxIMPLEMENT_APP(SmokeApp);
