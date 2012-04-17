//
// MandelbrotView.xaml.h
// Declaration of the MandelbrotView.xaml class.
//

#pragma once

#include "pch.h"
#include "MandelbrotView.g.h"

namespace MandelbrotViewer
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public ref class MandelbrotView sealed
	{
	public:
		MandelbrotView();

	protected:
		virtual void OnNavigatedTo(Windows::UI::Xaml::Navigation::NavigationEventArgs^ e) override;
	};
}
