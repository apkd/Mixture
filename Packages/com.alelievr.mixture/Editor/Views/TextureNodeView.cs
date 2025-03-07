using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.UIElements;
using UnityEditor.Experimental.GraphView;
using UnityEngine.UIElements;
using GraphProcessor;
using System.Linq;

namespace Mixture
{
	[NodeCustomEditor(typeof(TextureNode))]
	public class TextureNodeView : MixtureNodeView
	{
		TextureNode		textureNode;

		public override void Enable(bool fromInspector)
		{
			base.Enable(fromInspector);
            var textureField = this.Q(className: "unity-object-field") as ObjectField;

            textureField.RegisterValueChangedCallback(e => {
                ForceUpdatePorts();
            });
		}
	}
}